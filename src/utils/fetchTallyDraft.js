const fs = require('fs');
const path = require('path');

const TALLY_API_URL = 'https://api.tally.xyz/query';
const API_KEY = '365b418f59bd6dc4a0d7f23c2e8c12d982f156e9069695a6f0a2dcc3232448df';

function usage() {
    console.log('Usage: node fetchTallyDraft.js <DRAFT_URL_OR_ID> <OUTPUT_DIR>');
    console.log('');
    console.log('Examples:');
    console.log('  node src/utils/fetchTallyDraft.js https://www.tally.xyz/gov/ens/draft/2786603872288769996 src/ens/proposals/ep-6-32');
    console.log('  node src/utils/fetchTallyDraft.js 2786603872288769996 src/ens/proposals/ep-6-32');
    process.exit(1);
}

function parseDraftId(input) {
    // Accept full Tally draft URL or raw ID
    const urlMatch = input.match(/\/draft\/(\d+)/);
    if (urlMatch) return urlMatch[1];
    if (/^\d+$/.test(input)) return input;
    console.error(`Error: Cannot parse draft ID from "${input}"`);
    process.exit(1);
}

async function fetchTallyDraft(draftId, outputDir) {
    const query = `
query Proposal {
    proposal(input: {id: "${draftId}", isLatest: true}) {
        id
        createdAt
        creator {
            address
            name
        }
        executableCalls {
            target
            calldata
            value
        }
        metadata {
            description
        }
    }
}
`;

    try {
        console.log(`Fetching draft proposal ${draftId} from Tally API...`);

        const response = await fetch(TALLY_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Api-Key': API_KEY
            },
            body: JSON.stringify({ query })
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`Response body: ${errorText}`);
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();

        if (data.errors) {
            throw new Error(`GraphQL error: ${JSON.stringify(data.errors)}`);
        }

        const proposal = data.data.proposal;

        if (!proposal) {
            throw new Error(`Draft proposal ${draftId} not found`);
        }

        const executableCalls = proposal.executableCalls;
        const description = proposal.metadata?.description || '';

        if (!executableCalls || executableCalls.length === 0) {
            throw new Error('No executable calls found in the draft proposal');
        }

        console.log(`Found ${executableCalls.length} executable call(s)`);

        // Log draft information
        console.log(`\nDraft Proposal Information:`);
        console.log(`  ID: ${proposal.id || draftId}`);
        if (proposal.createdAt) console.log(`  Created: ${proposal.createdAt}`);
        if (proposal.creator) {
            console.log(`  Proposer: ${proposal.creator.name || proposal.creator.address || 'Unknown'}`);
            console.log(`  Address: ${proposal.creator.address || 'Unknown'}`);
        }

        // Create the calldata structure
        const calldataJson = {
            proposalId: draftId,
            type: 'draft',
            executableCalls: executableCalls.map(call => ({
                target: call.target,
                calldata: call.calldata,
                value: call.value || "0"
            }))
        };

        // Ensure output directory exists
        const resolvedDir = path.resolve(outputDir);
        fs.mkdirSync(resolvedDir, { recursive: true });

        const jsonPath = path.join(resolvedDir, 'proposalCalldata.json');
        const mdPath = path.join(resolvedDir, 'proposalDescription.md');

        fs.writeFileSync(jsonPath, JSON.stringify(calldataJson, null, 2));
        console.log(`\nWrote ${jsonPath}`);

        fs.writeFileSync(mdPath, description);
        console.log(`Wrote ${mdPath}`);

        // Log each call for verification
        executableCalls.forEach((call, index) => {
            console.log(`\nCall ${index + 1}:`);
            console.log(`  Target: ${call.target}`);
            console.log(`  Value: ${call.value || "0"}`);
            console.log(`  Calldata: ${call.calldata.substring(0, 66)}...`);
        });

        console.log('\nDone!');

    } catch (error) {
        console.error('Error fetching draft proposal:', error.message);
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

    const draftId = parseDraftId(args[0]);
    const outputDir = args[1];

    fetchTallyDraft(draftId, outputDir);
}

module.exports = { fetchTallyDraft };
