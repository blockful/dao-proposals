const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ANTICAPTURE_API_BASE = 'https://app.anticapture.com/api/gateful';

function usage() {
    console.log('Usage: node fetchDraft.js <DRAFT_URL_OR_ID> <OUTPUT_DIR>');
    console.log('');
    console.log('Fetches a proposal draft from the Anticapture draft API.');
    console.log('');
    console.log('Examples:');
    console.log('  node src/utils/fetchDraft.js "https://app.anticapture.com/ens/proposals/new?draftId=5daf1183-4216-47b0-8599-ccdaecf25538" src/ens/proposals/ep-topic-name');
    console.log('  node src/utils/fetchDraft.js "https://ens.gov.blockful.io/proposals/new?draftId=5daf1183-4216-47b0-8599-ccdaecf25538" src/ens/proposals/ep-topic-name');
    console.log('  node src/utils/fetchDraft.js 5daf1183-4216-47b0-8599-ccdaecf25538 src/ens/proposals/ep-topic-name');
    process.exit(1);
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseDraftRef(input) {
    if (UUID_RE.test(input)) {
        console.log('Detected DAO: ens (default — no DAO in input)');
        return { dao: 'ens', draftId: input.toLowerCase(), source: null };
    }

    if (/tally\.xyz/i.test(input)) {
        console.error('Error: Tally draft URLs are not supported — drafts are fetched from the Anticapture draft API.');
        console.error('Pass an Anticapture draft URL (...?draftId=<uuid>) or a raw draft UUID.');
        process.exit(1);
    }

    const idMatch = input.match(/[?&]draftId=([0-9a-f-]{36})/i);
    if (!idMatch) {
        console.error(`Error: cannot parse a draft ID from "${input}"`);
        usage();
    }

    // DAO slug lives in the path on app.anticapture.com/<dao>/proposals/... or in the
    // subdomain on <dao>.gov.blockful.io
    const anticaptureMatch = input.match(/anticapture\.com\/([^/]+)\/proposals/i);
    const gatefulMatch = input.match(/\/\/([^./]+)\.gov\.blockful\.io\//i);
    const dao = ((anticaptureMatch && anticaptureMatch[1]) || (gatefulMatch && gatefulMatch[1]) || 'ens').toLowerCase();
    console.log(`Detected DAO: ${dao}${anticaptureMatch || gatefulMatch ? '' : ' (default — no DAO in URL)'}`);

    return { dao, draftId: idMatch[1].toLowerCase(), source: input };
}

// Split "bytes32,(address,uint256)[],string" at top-level commas only
function splitTypes(s) {
    const out = [];
    let depth = 0;
    let cur = '';
    for (const ch of s) {
        if (ch === '(') depth++;
        if (ch === ')') depth--;
        if (ch === ',' && depth === 0) {
            out.push(cur);
            cur = '';
            continue;
        }
        cur += ch;
    }
    if (cur) out.push(cur);
    return out;
}

// "uint256 amount" -> "uint256"; pure types contain no spaces
function stripParamName(t) {
    return t.trim().replace(/\s+\w+$/, '');
}

// Format one JSON arg for `cast calldata`, guided by its ABI type
function formatArg(type, value) {
    const arrayMatch = type.match(/^(.*)\[\d*\]$/);
    if (arrayMatch) {
        if (!Array.isArray(value)) throw new Error(`expected array for ${type}, got ${JSON.stringify(value)}`);
        return '[' + value.map((v) => formatArg(arrayMatch[1], v)).join(',') + ']';
    }
    if (type.startsWith('(')) {
        const componentTypes = splitTypes(type.slice(1, -1)).map(stripParamName);
        const values = Array.isArray(value) ? value : Object.values(value);
        if (values.length !== componentTypes.length) {
            throw new Error(`tuple arity mismatch for ${type}: ${JSON.stringify(value)}`);
        }
        return '(' + values.map((v, i) => formatArg(componentTypes[i], v)).join(',') + ')';
    }
    return String(value);
}

// Draft actions carry functionName + args, not encoded calldata — encode with cast
function encodeCalldata(action) {
    if (action.calldata) return action.calldata;
    if (!action.functionName) return '0x'; // plain ETH transfer

    const sig = action.functionName;
    const open = sig.indexOf('(');
    const close = sig.lastIndexOf(')');
    if (open === -1 || close === -1) {
        throw new Error(`action functionName "${sig}" is not a full signature like "grantRole(bytes32,address)"`);
    }

    const paramTypes = splitTypes(sig.slice(open + 1, close)).map(stripParamName);
    const args = action.args || [];
    if (args.length !== paramTypes.length) {
        throw new Error(`arg count mismatch for ${sig}: ${JSON.stringify(args)}`);
    }
    const castArgs = args.map((arg, i) => formatArg(paramTypes[i], arg));

    try {
        return execFileSync('cast', ['calldata', sig, ...castArgs], { encoding: 'utf-8' }).trim();
    } catch (err) {
        if (err.code === 'ENOENT') {
            throw new Error('`cast` not found — Foundry is required to encode draft calldata');
        }
        throw new Error(`cast calldata failed for ${sig}: ${err.stderr || err.message}`);
    }
}

async function fetchDraft(dao, draftId, outputDir, source) {
    try {
        console.log(`Fetching draft ${draftId} from the Anticapture API...`);

        const response = await fetch(`${ANTICAPTURE_API_BASE}/${dao}/proposal/drafts/${draftId}`);
        if (response.status === 404) {
            throw new Error(`Draft ${draftId} not found for DAO "${dao}"`);
        }
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`Response body: ${errorText}`);
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const draft = await response.json();
        const actions = draft.actions || [];
        if (actions.length === 0) {
            throw new Error('No actions found in the draft');
        }

        console.log(`Found ${actions.length} action(s)`);
        console.log(`\nDraft Information:`);
        console.log(`  ID: ${draft.id || draftId}`);
        console.log(`  DAO: ${draft.daoId || dao}`);
        console.log(`  Title: ${draft.title || '(untitled)'}`);
        console.log(`  Author: ${draft.author || 'Unknown'}`);
        console.log(`  Created: ${draft.createdAt || 'Unknown'} — updated: ${draft.updatedAt || 'Unknown'}`);

        const executableCalls = actions.map((action, index) => {
            if (!action.contractAddress) {
                throw new Error(`action ${index + 1} has no contractAddress: ${JSON.stringify(action)}`);
            }
            return {
                target: action.contractAddress,
                calldata: encodeCalldata(action),
                value: String(action.value ?? '0'),
            };
        });

        const calldataJson = {
            source: source || `https://app.anticapture.com/${dao}/proposals/new?draftId=${draftId}`,
            draftId,
            author: draft.author,
            fetchedAt: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
            executableCalls,
        };

        let description = `# ${draft.title}\n\n${draft.body || ''}`;
        if (!description.endsWith('\n')) description += '\n';

        const resolvedDir = path.resolve(outputDir);
        fs.mkdirSync(resolvedDir, { recursive: true });

        const jsonPath = path.join(resolvedDir, 'proposalCalldata.json');
        const mdPath = path.join(resolvedDir, 'proposalDescription.md');

        fs.writeFileSync(jsonPath, JSON.stringify(calldataJson, null, 2));
        console.log(`\nWrote ${jsonPath}`);

        fs.writeFileSync(mdPath, description);
        console.log(`Wrote ${mdPath}`);

        executableCalls.forEach((call, index) => {
            console.log(`\nCall ${index + 1}:`);
            console.log(`  Target: ${call.target}`);
            console.log(`  Function: ${actions[index].functionName || '(raw calldata)'}`);
            console.log(`  Value: ${call.value}`);
            console.log(`  Calldata: ${call.calldata.substring(0, 66)}${call.calldata.length > 66 ? '...' : ''}`);
        });

        console.log('\nDone!');
    } catch (error) {
        console.error('Error fetching draft:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    if (typeof fetch === 'undefined') {
        console.error('This script requires Node.js 18+ for fetch support');
        process.exit(1);
    }

    const args = process.argv.slice(2);
    if (args.length < 2) usage();

    const { dao, draftId, source } = parseDraftRef(args[0]);
    const outputDir = args[1];

    fetchDraft(dao, draftId, outputDir, source);
}

module.exports = { fetchDraft };
