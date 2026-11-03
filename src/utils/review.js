const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');
const { parseArgs } = require('util');

const { fetchLiveProposal } = require('./fetchLiveProposal');
const { fetchDraft } = require('./fetchDraft');

const registry = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'dao-registry.json'), 'utf-8'));

const TEST_FILE = 'calldataCheck.t.sol';
const JSON_FILE = 'proposalCalldata.json';
const DESCRIPTION_FILE = 'proposalDescription.md';
const PROPOSAL_CREATED = 'ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)';
const CHAIN_CHECKED_TYPES = ['governor-timelock'];
const SKELETON_BASES = ['ENS_Governance', 'UNI_Governance'];
const DESCRIPTION_HASHED_BASES = ['ENS_Governance'];
const CI_PENDING_EXIT = 75;
const CI_WAIT_MS = 9 * 60 * 1000;

function usage() {
    console.log(`Usage:
  node src/utils/review.js start <PROPOSAL_URL_OR_ID> [--name ep-x-y] [--here]
  node src/utils/review.js start --pre-draft --name ep-topic [--dao ens] [--here]
  node src/utils/review.js check <PROPOSAL_DIR> [--allow file]...
  node src/utils/review.js finish <PROPOSAL_DIR> --summary "what moves where" [--finding "text"]... [--note "text"]...
                                  [--wait] [--no-merge] [--dry-run] [--allow file]...`);
    process.exit(1);
}

function fail(message) {
    console.error(`Error: ${message}`);
    process.exit(1);
}

function sh(command, args, options = {}) {
    return execFileSync(command, args, { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'], ...options }).trim();
}

function repoRoot() {
    return sh('git', ['rev-parse', '--show-toplevel']);
}

function mainCheckout() {
    return path.dirname(sh('git', ['rev-parse', '--path-format=absolute', '--git-common-dir']));
}

function loadEnv(root) {
    const file = path.join(root, '.env');
    if (!fs.existsSync(file)) return;
    for (const line of fs.readFileSync(file, 'utf-8').split('\n')) {
        const match = line.match(/^\s*(?:export\s+)?(\w+)=(.*)$/);
        if (match && !process.env[match[1]]) process.env[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, '');
    }
}

// cast exits 0 on some connection errors, so check the RPC before trusting an empty read
function requireRpc() {
    const url = process.env.MAINNET_RPC_URL;
    const result = url ? spawnSync('cast', ['block-number', '--rpc-url', url], { encoding: 'utf-8' }) : null;
    if (!result || result.status !== 0 || !/^\d+$/.test(result.stdout.trim())) {
        fail('MAINNET_RPC_URL is missing or unreachable. Point it at an archive RPC in .env.');
    }
}

// ─── Proposal references ────────────────────────────────────────────

function daoFromUrl(input) {
    const match =
        input.match(/\/gov\/([^/]+)\/proposal/i) ||
        input.match(/\/\/([^./]+)\.gov\.blockful\.io/i) ||
        input.match(/anticapture\.com\/([^/]+)\//i);
    return match ? match[1].toLowerCase() : 'ens';
}

function parseRef(input) {
    const draft = input.match(/[?&]draftId=([0-9a-f-]{36})/i) || input.match(/^([0-9a-f]{8}-[0-9a-f-]{27})$/i);
    if (draft) return { phase: 'draft', dao: daoFromUrl(input), id: draft[1].toLowerCase() };

    const live = input.match(/\/proposals?\/(\d+)/) || input.match(/^(\d+)$/);
    if (live) return { phase: 'live', dao: daoFromUrl(input), id: live[1] };

    return null;
}

function proposalLink(daoKey, phase, id) {
    const dao = registry.daos[daoKey];
    if (phase === 'draft') {
        const site = dao.proposalUrl ? new URL(dao.proposalUrl).origin : `https://app.anticapture.com/${daoKey}`;
        return `${site}/proposals/new?draftId=${id}`;
    }
    if (phase !== 'live') return null;
    if (dao.proposalUrl) return dao.proposalUrl.replace('{id}', id);
    return dao.tallySlug ? `https://www.tally.xyz/gov/${dao.tallySlug}/proposal/${id}` : null;
}

function proposalTitle(description) {
    const line = description.split('\n').find((l) => l.trim()) || '';
    return line.replace(/^#+\s*/, '').trim();
}

function directoryName(daoKey, title) {
    const prefix = registry.daos[daoKey].proposalPrefix;
    const numbered = title.match(/^\[?(?:EP\s*)?(\d+)\.(\d+)\]?/i);
    if (numbered) return `${prefix}-${numbered[1]}-${numbered[2]}`;
    const words = title
        .replace(/\[[^\]]*\]/g, ' ')
        .toLowerCase()
        .replace(/[^a-z0-9 ]/g, ' ')
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 5);
    return `${prefix}-${words.join('-')}`;
}

function contractName(daoKey, name, phase) {
    const prefix = registry.daos[daoKey].contractNaming.split('{')[0];
    const words = name
        .replace(new RegExp(`^${registry.daos[daoKey].proposalPrefix}-`), '')
        .split('-')
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1));
    return `${prefix}${words.join('_')}${phase === 'live' ? '' : phase === 'draft' ? '_Draft' : ''}_Test`;
}

// ─── Chain reads ────────────────────────────────────────────────────

function decodeProposalCreated(data) {
    const bytes = Buffer.from(data.replace(/^0x/, ''), 'hex');
    const word = (offset) => BigInt(`0x${bytes.subarray(offset, offset + 32).toString('hex')}`);
    const number = (offset) => Number(word(offset));
    const blob = (offset) => bytes.subarray(offset + 32, offset + 32 + number(offset));
    const words = (offset) => Array.from({ length: number(offset) }, (_, i) => word(offset + 32 + 32 * i));
    const blobs = (offset) => {
        const base = offset + 32;
        return Array.from({ length: number(offset) }, (_, i) => blob(base + number(base + 32 * i)));
    };

    return {
        id: word(0),
        proposer: `0x${word(32).toString(16).padStart(40, '0')}`,
        targets: words(number(64)).map((t) => `0x${t.toString(16).padStart(40, '0')}`),
        values: words(number(96)),
        signatures: blobs(number(128)).map((s) => s.toString('utf-8')),
        calldatas: blobs(number(160)).map((c) => `0x${c.toString('hex')}`),
        description: Buffer.from(blob(number(256))),
    };
}

function readProposalEvent(daoKey, block, id) {
    const logs = JSON.parse(
        sh('cast', [
            'logs',
            '--from-block',
            String(block),
            '--to-block',
            String(block),
            '--address',
            registry.daos[daoKey].contracts.governor,
            PROPOSAL_CREATED,
            '--rpc-url',
            process.env.MAINNET_RPC_URL,
            '--json',
        ]),
    );
    return logs.map((log) => decodeProposalCreated(log.data)).find((event) => event.id === BigInt(id)) || null;
}

function callsDifferFromChain(calls, event) {
    const problems = [];
    if (calls.length !== event.targets.length) {
        problems.push(`${calls.length} calls in ${JSON_FILE}, ${event.targets.length} on-chain`);
        return problems;
    }
    calls.forEach((call, i) => {
        const selector = event.signatures[i] ? sh('cast', ['sig', event.signatures[i]]) : '';
        const onchain = selector ? `${selector}${event.calldatas[i].slice(2)}` : event.calldatas[i];
        if (call.target.toLowerCase() !== event.targets[i]) problems.push(`call ${i}: target differs from chain`);
        if (BigInt(call.value || 0) !== event.values[i]) problems.push(`call ${i}: value differs from chain`);
        if (call.calldata.toLowerCase() !== onchain.toLowerCase()) problems.push(`call ${i}: calldata differs from chain`);
    });
    return problems;
}

function isExecuted(daoKey, id) {
    const dao = registry.daos[daoKey];
    if (!CHAIN_CHECKED_TYPES.includes(dao.governanceType) || !process.env.MAINNET_RPC_URL) return false;
    const args = ['call', dao.contracts.governor, 'state(uint256)(uint8)', id, '--rpc-url', process.env.MAINNET_RPC_URL];
    const result = spawnSync('cast', args, { encoding: 'utf-8' });
    return result.status === 0 && result.stdout.trim() === '7';
}

function lookupName(address) {
    try {
        return sh('cast', ['lookup-address', address, '--rpc-url', process.env.MAINNET_RPC_URL]);
    } catch {
        return null;
    }
}

function hasVotes(daoKey, address) {
    const { governor, token } = registry.daos[daoKey].contracts;
    try {
        const rpc = ['--rpc-url', process.env.MAINNET_RPC_URL];
        const parse = (out) => BigInt(out.split(' ')[0]);
        const votes = parse(sh('cast', ['call', token, 'getVotes(address)(uint256)', address, ...rpc]));
        return votes >= parse(sh('cast', ['call', governor, 'proposalThreshold()(uint256)', ...rpc]));
    } catch {
        return false;
    }
}

// ─── Test skeleton ──────────────────────────────────────────────────

function skeleton({ daoKey, name, phase, dir, proposalId, block, proposer, proposerName, calls, draftLink }) {
    const dao = registry.daos[daoKey];
    const base = dao.baseTestContract;
    const importPath = `@${path.basename(dao.basePath)}/${path.basename(dao.baseTestFile)}`;
    const size = Math.max(calls, 1);
    const live = phase === 'live';
    const hashed = DESCRIPTION_HASHED_BASES.includes(base);
    const label = proposerName ? ` // ${proposerName}` : '';

    return `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ${base} } from "${importPath}";

${draftLink ? `// ${draftLink}\n` : ''}contract ${contractName(daoKey, name, phase)} is ${base} {
${live ? `    uint256 constant expectedProposalId = ${proposalId};\n\n` : ''}    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: ${block}, urlOrAlias: "mainnet" });
    }
${
    proposer
        ? `
    function _proposer() public pure override returns (address) {
        return ${proposer};${label}
    }
`
        : ''
}
    function _beforeProposal() public override {
${live && hashed ? '        assertEq(proposalId, expectedProposalId);\n' : ''}        // TODO: snapshot and check the state this proposal changes
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](${size});
        values = new uint256[](${size});
        calldatas = new bytes[](${size});
        signatures = new string[](${size});

        // TODO: derive every call from the proposal text and interfaces

${live && !hashed ? '        proposalId = expectedProposalId;\n' : ''}        description = ${phase === 'pre-draft' ? '"Pre-draft: description TBD"' : 'getDescriptionFromMarkdown()'};

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // TODO: assert every effect the proposal claims
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return ${live};
    }

    function dirPath() public pure override returns (string memory) {
        return "${phase === 'pre-draft' ? '' : dir}";
    }
}
`;
}

// ─── start ──────────────────────────────────────────────────────────

function addWorktree(daoKey, name) {
    const main = mainCheckout();
    const worktree = path.join(main, '.worktrees', name);
    if (fs.existsSync(worktree)) return worktree;

    sh('git', ['-C', main, 'fetch', '-q', 'origin', 'main']);
    const branch = `${daoKey}/${name}`;
    const exists = spawnSync('git', ['-C', main, 'rev-parse', '--verify', '-q', `refs/heads/${branch}`]).status === 0;
    const args = exists ? [worktree, branch] : ['--no-track', '-b', branch, worktree, 'origin/main'];
    sh('git', ['-C', main, 'worktree', 'add', '-q', ...args]);

    for (const shared of ['node_modules', '.env']) {
        if (fs.existsSync(path.join(main, shared))) {
            fs.symlinkSync(path.join('..', '..', shared), path.join(worktree, shared));
        }
    }
    return worktree;
}

async function start(input, flags) {
    const ref = flags['pre-draft'] ? { phase: 'pre-draft', dao: flags.dao || 'ens' } : parseRef(input || '');
    if (!ref) fail(`cannot tell which proposal "${input}" is. Pass a proposal URL, a draft URL or an on-chain ID.`);
    const dao = registry.daos[ref.dao];
    if (!dao) fail(`DAO "${ref.dao}" is not in src/dao-registry.json`);
    if (ref.phase === 'pre-draft' && !flags.name) fail('a pre-draft needs --name');

    loadEnv(repoRoot());
    loadEnv(mainCheckout());
    requireRpc();

    const fetched = fs.mkdtempSync(path.join(os.tmpdir(), 'review-'));
    if (ref.phase === 'live') {
        if (!dao.tallySlug) fail(`${dao.name} has no Tally slug, so fetch its proposal by hand.`);
        await fetchLiveProposal(ref.id, fetched, `eip155:1:${dao.contracts.governor}`);
    } else if (ref.phase === 'draft') {
        await fetchDraft(ref.dao, ref.id, fetched, input);
    }

    const jsonPath = path.join(fetched, JSON_FILE);
    const mdPath = path.join(fetched, DESCRIPTION_FILE);
    const fixture = fs.existsSync(jsonPath) ? JSON.parse(fs.readFileSync(jsonPath, 'utf-8')) : null;
    const title = fs.existsSync(mdPath) ? proposalTitle(fs.readFileSync(mdPath, 'utf-8')) : flags.name;
    const name = flags.name || directoryName(ref.dao, title);

    let event = null;
    if (ref.phase === 'live' && CHAIN_CHECKED_TYPES.includes(dao.governanceType)) {
        event = readProposalEvent(ref.dao, fixture.blockNumber, ref.id);
        if (!event) fail(`no ProposalCreated event for ${ref.id} at block ${fixture.blockNumber}`);
        const problems = callsDifferFromChain(fixture.executableCalls, event);
        if (problems.length) fail(`the fetched calls do not match the chain:\n  ${problems.join('\n  ')}`);
        fs.writeFileSync(mdPath, event.description);
    }

    const inWorktree = repoRoot() !== mainCheckout();
    const checkout = flags.here || inWorktree ? repoRoot() : addWorktree(ref.dao, name);
    const dir = path.join(dao.proposalsPath, name);
    const absolute = path.join(checkout, dir);
    fs.mkdirSync(absolute, { recursive: true });
    for (const file of fs.readdirSync(fetched)) fs.copyFileSync(path.join(fetched, file), path.join(absolute, file));
    if (ref.phase === 'draft' && !fixture) fs.rmSync(path.join(absolute, JSON_FILE), { force: true });

    const testPath = path.join(absolute, TEST_FILE);
    if (fs.existsSync(testPath)) {
        console.log(`\nKept the existing ${TEST_FILE}. Update it for the ${ref.phase} phase.`);
    } else if (SKELETON_BASES.includes(dao.baseTestContract)) {
        const rpc = process.env.MAINNET_RPC_URL;
        const block = fixture && fixture.blockNumber ? fixture.blockNumber : sh('cast', ['block-number', '--rpc-url', rpc]);
        const author = event ? event.proposer : fixture && fixture.author;
        const proposer = author && (event || hasVotes(ref.dao, author)) ? sh('cast', ['to-check-sum-address', author]) : null;
        const calls = fixture ? fixture.executableCalls.length : 1;
        const proposerName = proposer ? lookupName(proposer) : null;
        const draftLink = ref.phase === 'draft' && !fixture ? proposalLink(ref.dao, 'draft', ref.id) : null;
        const fields = { daoKey: ref.dao, name, phase: ref.phase, dir, proposalId: ref.id, draftLink };
        fs.writeFileSync(testPath, skeleton({ ...fields, block, proposer, proposerName, calls }));
        sh('forge', ['fmt', testPath], { cwd: checkout });
    } else {
        console.log(`\nNo skeleton for ${dao.baseTestContract}. Copy the newest test under ${dao.proposalsPath}.`);
    }

    console.log(`\nProposal: ${title}`);
    console.log(`Phase: ${ref.phase}`);
    console.log(`Checkout: ${checkout}`);
    console.log(`Directory: ${dir}`);
    if (ref.phase === 'draft' && !fixture) {
        console.log('\nNO ACTIONS ATTACHED. Compare the test against the calls listed in the description.');
    }
    console.log(`\nNext: fill in ${TEST_FILE}, then run this from the checkout:`);
    console.log(`  node src/utils/review.js check "${dir}"`);
}

// ─── check ──────────────────────────────────────────────────────────

function phaseOf(absolute) {
    const jsonPath = path.join(absolute, JSON_FILE);
    if (fs.existsSync(jsonPath)) {
        const fixture = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
        return { phase: fixture.proposalId ? 'live' : 'draft', fixture };
    }
    if (fs.existsSync(path.join(absolute, DESCRIPTION_FILE))) return { phase: 'draft', fixture: null };
    return { phase: 'pre-draft', fixture: null };
}

function commentLines(source) {
    const lines = [];
    let inBlock = false;
    for (const raw of source.split('\n')) {
        const line = raw.replace(/"(?:[^"\\]|\\.)*"/g, '""');
        if (inBlock) {
            lines.push(raw);
            if (line.includes('*/')) inBlock = false;
        } else if (line.includes('/*')) {
            lines.push(raw);
            if (!line.includes('*/')) inBlock = true;
        } else if (line.includes('//') && !line.includes('SPDX-License-Identifier')) {
            lines.push(raw);
        }
    }
    return lines;
}

function functionBody(source, name) {
    const start = source.search(new RegExp(`function ${name}\\s*\\(`));
    if (start === -1) return null;
    const open = source.indexOf('{', start);
    let depth = 0;
    for (let i = open; i < source.length; i++) {
        if (source[i] === '{') depth++;
        if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
    }
    return null;
}

function lintTest(source, { phase, calls, dir }) {
    const problems = [];
    const code = source
        .replace(/\/\*[\s\S]*?\*\//g, '')
        .split('\n')
        .map((line) => line.replace(/\/\/.*$/, ''))
        .join('\n');

    if (/TODO/.test(source)) problems.push('TODOs are left in the test');
    if (!source.includes('pragma solidity >=0.8.25 <0.9.0;')) problems.push('pragma must be >=0.8.25 <0.9.0');

    const comments = commentLines(source);
    const limit = Math.max(3, calls + 2);
    if (comments.length > limit) problems.push(`${comments.length} comment lines, the limit here is ${limit}`);
    if (/\/\*\*|@(title|notice|dev|param)\b/.test(source)) problems.push('remove the NatSpec blocks');

    if (/proposalCalldata/.test(code)) problems.push(`the test must not read ${JSON_FILE}: derive the calls`);
    const calldata = functionBody(code, '_generateCallData') || '';
    if (/hex"|\b0x[0-9a-fA-F]{65,}\b/.test(calldata)) problems.push('hex blob in the calls: derive it from an interface');
    if (/\b0x[0-9a-fA-F]{8}\b/.test(calldata)) problems.push('hardcoded selector: use Interface.method.selector');

    for (const hook of ['_beforeProposal', '_afterExecution']) {
        const body = functionBody(code, hook);
        const checks = body === null ? null : body.replace(/.*expectedProposalId.*/g, '');
        if (checks !== null && !/assert|expectRevert/.test(checks)) problems.push(`${hook}() checks no state`);
    }

    const submitted = functionBody(code, '_isProposalSubmitted');
    if (submitted !== null && !submitted.includes(`return ${phase === 'live'}`)) {
        problems.push(`_isProposalSubmitted() must return ${phase === 'live'} for a ${phase} review`);
    }
    const dirPath = functionBody(code, 'dirPath');
    if (dirPath !== null && !dirPath.includes(`"${phase === 'pre-draft' ? '' : dir}"`)) {
        problems.push(`dirPath() must return "${phase === 'pre-draft' ? '' : dir}"`);
    }
    if (phase === 'live' && !/expectedProposalId|PROPOSAL_ID|_proposalId|proposalId\s*=\s*\d/.test(code)) {
        problems.push('a live review must pin the on-chain proposal ID');
    }
    return problems;
}

function extraFiles(absolute, allowed) {
    const known = new Set([TEST_FILE, JSON_FILE, DESCRIPTION_FILE, ...allowed]);
    return fs
        .readdirSync(absolute, { recursive: true, withFileTypes: true })
        .filter((entry) => entry.isFile())
        .map((entry) => path.relative(absolute, path.join(entry.parentPath || entry.path, entry.name)))
        .filter((file) => !known.has(file) && ![...known].some((k) => file.startsWith(`${k}/`)));
}

function runTests(root, dir) {
    const result = spawnSync('forge', ['test', '--match-path', `${dir}/*`, '--json'], {
        cwd: root,
        encoding: 'utf-8',
        maxBuffer: 1024 * 1024 * 256,
    });
    let suites;
    try {
        suites = JSON.parse(result.stdout);
    } catch {
        return { passed: 0, failures: [(result.stderr || 'forge produced no output').trim().slice(0, 800)] };
    }
    const tests = Object.values(suites).flatMap((suite) => Object.entries(suite.test_results));
    const failures = tests.filter(([, t]) => t.status !== 'Success').map(([n, t]) => `${n}: ${t.reason || t.status}`);
    return { passed: tests.length - failures.length, failures };
}

function expectFailureWhenTampered(root, dir, file, tamper) {
    const target = path.join(root, dir, file);
    const original = fs.readFileSync(target);
    try {
        fs.writeFileSync(target, tamper(original.toString('utf-8')));
        return runTests(root, dir).failures.length > 0;
    } finally {
        fs.writeFileSync(target, original);
    }
}

function tamperFixture(text) {
    const fixture = JSON.parse(text);
    const call = fixture.executableCalls[0];
    const last = call.calldata.slice(-1) === '0' ? '1' : '0';
    if (call.calldata.length > 2) call.calldata = `${call.calldata.slice(0, -1)}${last}`;
    else call.value = String(BigInt(call.value || 0) + 1n);
    return JSON.stringify(fixture, null, 2);
}

function check(dirArg, flags) {
    const root = repoRoot();
    loadEnv(root);
    loadEnv(mainCheckout());
    requireRpc();
    const dir = path.relative(root, path.resolve(dirArg));
    const absolute = path.join(root, dir);
    const testPath = path.join(absolute, TEST_FILE);
    if (!fs.existsSync(testPath)) fail(`${testPath} does not exist`);

    const daoKey = Object.keys(registry.daos).find((key) => dir.startsWith(`${registry.daos[key].proposalsPath}/`));
    const { phase, fixture } = phaseOf(absolute);
    const source = fs.readFileSync(testPath, 'utf-8');
    const declared = source.match(/new address\[\]\((\d+)\)/);
    const calls = fixture ? fixture.executableCalls.length : Number(declared ? declared[1] : 0);
    const results = [];
    const record = (name, problems) => results.push({ name, problems });

    record('files', extraFiles(absolute, flags.allow || []).map((file) => `extra file: ${file}`));
    record('test shape', lintTest(source, { phase, calls, dir }));

    const fmt = spawnSync('forge', ['fmt', '--check', testPath], { cwd: root, encoding: 'utf-8' });
    record('formatting', fmt.status === 0 ? [] : ['run forge fmt on the test']);

    const dao = daoKey && registry.daos[daoKey];
    if (phase === 'live' && dao && CHAIN_CHECKED_TYPES.includes(dao.governanceType)) {
        const event = readProposalEvent(daoKey, fixture.blockNumber, fixture.proposalId);
        const problems = event
            ? callsDifferFromChain(fixture.executableCalls, event)
            : [`no ProposalCreated event for ${fixture.proposalId}`];
        if (event && !fs.readFileSync(path.join(absolute, DESCRIPTION_FILE)).equals(event.description)) {
            problems.push(`${DESCRIPTION_FILE} differs from the on-chain description`);
        }
        record('files match the chain', problems);
    } else if (phase === 'live') {
        console.log(`not checked: ${dao ? dao.governanceType : 'unknown DAO'} events are not read here`);
    }

    const { passed, failures } = runTests(root, dir);
    const mismatch = failures.some((f) => /mismatch|unknown proposal id|!=/i.test(f));
    record('test passes', passed === 0 && !failures.length ? ['no tests ran'] : failures);

    if (failures.length === 0 && passed > 0 && fixture && fixture.executableCalls.length) {
        const caught = expectFailureWhenTampered(root, dir, JSON_FILE, tamperFixture);
        record('fails on altered calldata', caught ? [] : ['the test still passes with altered calldata']);
    }
    if (failures.length === 0 && passed > 0 && phase === 'live' && dao && DESCRIPTION_HASHED_BASES.includes(dao.baseTestContract)) {
        const caught = expectFailureWhenTampered(root, dir, DESCRIPTION_FILE, (text) => `${text} `);
        record('fails on altered description', caught ? [] : ['the test still passes with an altered description']);
    }

    for (const { name, problems } of results) {
        console.log(`${problems.length ? 'FAIL' : 'ok  '} ${name}`);
        for (const problem of problems) console.log(`     ${problem}`);
    }
    const ok = results.every((r) => r.problems.length === 0);
    if (mismatch && !source.includes('TODO')) {
        console.log('\nA mismatch is a finding. Do not approve or finish this review. Report it.');
    }
    console.log(ok ? `\nPassed. ${phase} review, ${passed} test(s).` : '\nNot ready.');
    return ok;
}

// ─── finish ─────────────────────────────────────────────────────────

function cleanSummary(summary) {
    return summary.trim().replace(/\.$/, '');
}

function reviewLabel(dir, title) {
    const name = path.basename(dir);
    const numbered = name.match(/^ep-(\d+)-(\d+)$/);
    if (numbered) return `EP ${numbered[1]}.${numbered[2]}`;
    const cleaned = (title || '').replace(/\[[^\]]*\]/g, '').trim();
    return cleaned || name.replace(/^(ep|proposal)-/, '').replace(/-/g, ' ');
}

function prTitle(daoKey, dir, phase, title) {
    const kind = phase === 'live' ? '' : `${phase} `;
    return `test(${daoKey}): validate ${reviewLabel(dir, title)} ${kind}calldata`;
}

function countOf(findings) {
    return findings.length === 1 ? 'one finding' : `${findings.length} findings`;
}

function prBody({ phase, link, summary, noActions, findings = [] }) {
    const noun = phase === 'draft' ? 'this draft' : 'this proposal';
    const subject = link ? `[${noun}](${link})` : phase === 'pre-draft' ? 'this pre-draft' : noun;
    const endings = [];
    if (noActions) endings.push('The draft has no actions attached, so the calls are checked against its description.');
    if (findings.length) endings.push(`It has ${countOf(findings)}.`);
    else if (!noActions) endings.push(phase === 'pre-draft' ? 'It executes as intended on a fork.' : 'Calldata matches.');
    return `Validates ${subject}: ${cleanSummary(summary)}. ${endings.join(' ')}`;
}

function forumComment({ phase, link, summary, notes, findings = [], noActions, executed, sha, dir }) {
    const file = `https://github.com/blockful/dao-proposals/blob/${sha}/${encodeURI(dir)}/${TEST_FILE}`;
    const s = cleanSummary(summary);
    const tests =
        phase === 'live'
            ? `The simulation and tests of the **live** proposal can be found [here](${file}).`
            : `All simulations and tests are available [here](${file}).`;
    const heading =
        phase === 'live'
            ? '## Live proposal calldata security verification'
            : `## ${phase === 'draft' ? 'Draft' : 'Pre-draft'} proposal calldata security review`;
    const proposal = link ? `[proposal](${link})` : 'proposal';
    const live = executed
        ? `This ${proposal} has already executed.`
        : link
          ? `This proposal is finally [live](${link})!`
          : 'This proposal is finally live!';
    const intro = phase === 'live' ? [live] : [];
    const issues = findings.length === 1 ? 'one issue' : `${findings.length} issues`;
    const outcome = findings.length
        ? [
              `What it does: ${s}. We found ${issues} ${executed ? 'worth noting' : `to address before ${phase === 'live' ? 'voting ends' : 'it goes on-chain'}`}:`,
              findings.map((f, i) => `${i + 1}. ${f.trim()}`).join('\n'),
              tests,
          ]
        : phase === 'live'
          ? [`Calldata executed the expected outcome: ${s}. ${tests}`]
          : [`The calldata ${phase === 'draft' ? 'draft ' : ''}executes successfully and achieves the expected outcome of the proposal: ${s}. ${tests}`];
    const extra = noActions
        ? ['The draft has no actions attached, so this review compares against the calls listed in its description.']
        : [];
    const opening = [heading, ...intro, ...outcome];
    const verify = [
        'To verify locally:',
        '1. Clone: `git clone https://github.com/blockful/dao-proposals.git && cd dao-proposals`',
        `2. Checkout: \`git checkout ${sha.slice(0, 7)} && npm install\``,
        `3. Run with an archive RPC in \`MAINNET_RPC_URL\`: \`forge test --match-path "${dir}/*" -vv\``,
    ].join('\n');
    return [...opening, ...extra, ...notes.map((n) => n.trim()), verify].join('\n\n');
}

function ciState(checks) {
    if (!checks || !checks.length) return { state: 'pending', names: ['no checks reported yet'] };
    const name = (c) => c.name || c.context;
    const badConclusions = ['FAILURE', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED', 'STARTUP_FAILURE'];
    const isFailed = (c) => badConclusions.includes(c.conclusion) || ['FAILURE', 'ERROR'].includes(c.state);
    const isPending = (c) => (c.status && c.status !== 'COMPLETED') || ['PENDING', 'EXPECTED'].includes(c.state);
    const failed = checks.filter(isFailed);
    if (failed.length) return { state: 'failed', names: failed.map(name) };
    const pending = checks.filter(isPending);
    if (pending.length) return { state: 'pending', names: pending.map(name) };
    return { state: 'passed', names: [] };
}

function changedFiles() {
    const entries = execFileSync('git', ['status', '--porcelain', '-z'], { encoding: 'utf-8' }).split('\0');
    const files = [];
    for (let i = 0; i < entries.length; i++) {
        if (!entries[i]) continue;
        files.push(entries[i].slice(3));
        if (/^[RC]/.test(entries[i])) i++;
    }
    return files;
}

function mergedHasReview(sha, dir) {
    sh('git', ['fetch', '-q', 'origin', 'main']);
    const differs = spawnSync('git', ['diff', '--quiet', sha, '--', dir]).status !== 0;
    const untracked = sh('git', ['ls-files', '--others', '--exclude-standard', '--', dir]);
    return !differs && !untracked;
}

function viewPr(number) {
    return JSON.parse(sh('gh', ['pr', 'view', String(number), '--json', 'number,url,state,mergeCommit,statusCheckRollup']));
}

function finish(dirArg, flags) {
    if (!flags.summary) fail('finish needs --summary "what moves where"');
    const root = repoRoot();
    loadEnv(root);
    loadEnv(mainCheckout());
    const dir = path.relative(root, path.resolve(dirArg));
    const absolute = path.join(root, dir);
    const daoKey = Object.keys(registry.daos).find((key) => dir.startsWith(`${registry.daos[key].proposalsPath}/`));
    if (!daoKey) fail(`${dir} is not under a DAO's proposals directory`);

    const { phase, fixture } = phaseOf(absolute);
    const noActions = phase === 'draft' && !fixture;
    const id = fixture && (fixture.proposalId || fixture.draftId);
    const source = fs.readFileSync(path.join(absolute, TEST_FILE), 'utf-8');
    const draftLink = source.match(/https:\/\/\S+draftId=[0-9a-f-]{36}/i);
    const link = id ? proposalLink(daoKey, phase, id) : draftLink && draftLink[0];
    const descriptionPath = path.join(absolute, DESCRIPTION_FILE);
    const proposal = fs.existsSync(descriptionPath) ? proposalTitle(fs.readFileSync(descriptionPath, 'utf-8')) : null;
    const title = prTitle(daoKey, dir, phase, proposal);
    const executed = phase === 'live' && isExecuted(daoKey, fixture.proposalId);
    const findings = flags.finding || [];
    const body = prBody({ phase, link, summary: flags.summary, noActions, findings });
    const notes = flags.note || [];
    const fields = { phase, link, summary: flags.summary, notes, findings, noActions, executed, dir };
    const comment = (sha) => forumComment({ ...fields, sha });
    const printComment = (sha) => {
        console.log('\n--- forum comment ---\n');
        console.log(comment(sha));
    };

    const branch = sh('git', ['branch', '--show-current']);
    if (!branch || branch === 'main') fail('run finish from the review branch, not main');

    const existing = flags['dry-run']
        ? []
        : JSON.parse(sh('gh', ['pr', 'list', '--head', branch, '--state', 'all', '--json', 'number,state,mergeCommit']));
    const open = existing.find((pr) => pr.state === 'OPEN');
    const merged = existing.find((pr) => pr.state === 'MERGED');
    if (!open && merged && mergedHasReview(merged.mergeCommit.oid, dir)) {
        console.log(`Already merged as ${merged.mergeCommit.oid.slice(0, 7)}.`);
        printComment(merged.mergeCommit.oid);
        return;
    }

    if (!check(dir, flags)) process.exit(1);

    if (flags['dry-run']) {
        console.log(`\n--- pull request ---\n\n${title}\n\n${body}`);
        printComment(sh('git', ['rev-parse', 'HEAD']));
        return;
    }

    const outside = changedFiles().filter((file) => !file.startsWith(`${dir}/`));
    if (outside.length) fail(`uncommitted changes outside the review:\n  ${outside.join('\n  ')}`);

    sh('git', ['add', '--', dir]);
    if (spawnSync('git', ['diff', '--cached', '--quiet']).status !== 0) sh('git', ['commit', '-q', '-m', title]);
    sh('git', ['push', '-q', '-u', 'origin', 'HEAD']);

    let number = open ? open.number : null;
    if (number) {
        sh('gh', ['pr', 'edit', String(number), '--body', body]);
    } else {
        const url = sh('gh', ['pr', 'create', '--base', 'main', '--title', title, '--body', body]);
        number = url.split('/').pop();
    }
    const url = viewPr(number).url;
    console.log(`\nPR: ${url}`);

    if (flags['no-merge']) {
        console.log('Not merging (--no-merge).');
        printComment(sh('git', ['rev-parse', 'HEAD']));
        return;
    }

    let ci = ciState(viewPr(number).statusCheckRollup);
    const deadline = Date.now() + CI_WAIT_MS;
    while (ci.state === 'pending' && flags.wait && Date.now() < deadline) {
        spawnSync('sleep', ['20']);
        ci = ciState(viewPr(number).statusCheckRollup);
    }
    if (ci.state === 'failed') fail(`CI failed: ${ci.names.join(', ')}. Fix it and run finish again.`);
    if (ci.state === 'pending') {
        console.log(`CI is still running (${ci.names.join(', ')}). Run finish again once it passes, or add --wait.`);
        process.exit(CI_PENDING_EXIT);
    }

    sh('gh', ['pr', 'merge', String(number), '--squash', '--subject', `${title} (#${number})`, '--body', '']);
    const sha = viewPr(number).mergeCommit.oid;
    console.log(`Merged as ${sha.slice(0, 7)}.`);
    printComment(sha);
}

async function main() {
    const { values, positionals } = parseArgs({
        allowPositionals: true,
        options: {
            name: { type: 'string' },
            dao: { type: 'string' },
            summary: { type: 'string' },
            note: { type: 'string', multiple: true },
            finding: { type: 'string', multiple: true },
            allow: { type: 'string', multiple: true },
            here: { type: 'boolean' },
            wait: { type: 'boolean' },
            'pre-draft': { type: 'boolean' },
            'no-merge': { type: 'boolean' },
            'dry-run': { type: 'boolean' },
        },
    });
    const [command, target] = positionals;
    if (command === 'start') return start(target, values);
    if (command === 'check' && target) return process.exit(check(target, values) ? 0 : 1);
    if (command === 'finish' && target) return finish(target, values);
    usage();
}

if (require.main === module) main();

module.exports = {
    parseRef,
    proposalLink,
    proposalTitle,
    directoryName,
    contractName,
    decodeProposalCreated,
    skeleton,
    changedFiles,
    commentLines,
    lintTest,
    prTitle,
    prBody,
    forumComment,
    ciState,
};
