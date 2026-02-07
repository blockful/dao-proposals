const fs = require('fs');
const path = require('path');

const TALLY_API_URL = 'https://api.tally.xyz/query';

async function fetchDraftProposal(draftId) {
    if (!draftId) {
        console.error('Error: Draft proposal ID is required');
        console.log('Usage: node fetchDraftProposal.js <DRAFT_ID>');
        console.log('Example: node fetchDraftProposal.js 2786603872288769996');
        process.exit(1);
    }

    // Build query with the draft ID embedded
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
                'Api-Key': '365b418f59bd6dc4a0d7f23c2e8c12d982f156e9069695a6f0a2dcc3232448df'
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
        if (proposal.createdAt) {
            console.log(`  Created: ${proposal.createdAt}`);
        }
        if (proposal.creator) {
            console.log(`  Proposer: ${proposal.creator.name || proposal.creator.address || 'Unknown'}`);
        }

        // Create the draft calldata structure
        const draftCalldata = {
            proposalId: draftId,
            type: 'draft',
            executableCalls: executableCalls.map(call => ({
                target: call.target,
                calldata: call.calldata,
                value: call.value || "0"
            }))
        };

        // Define output paths
        const projectRoot = path.resolve(__dirname, '../../');
        const outputDir = path.join(projectRoot, '');
        const jsonOutputPath = path.join(outputDir, 'draftCalldata.json');
        const mdOutputPath = path.join(outputDir, 'proposalDescription.md');
        
        // Write JSON file
        fs.writeFileSync(jsonOutputPath, JSON.stringify(draftCalldata, null, 2));
        console.log(`\nSuccessfully created ${jsonOutputPath}`);
        
        // Write description as markdown file
        fs.writeFileSync(mdOutputPath, description);
        console.log(`Successfully created ${mdOutputPath}`);
        
        console.log(`\nSummary:`);
        console.log(`  Executable calls: ${executableCalls.length}`);
        console.log(`  Description length: ${description.length} characters`);
        
        // Log each call for verification
        executableCalls.forEach((call, index) => {
            console.log(`\nCall ${index + 1}:`);
            console.log(`  Target: ${call.target}`);
            console.log(`  Value: ${call.value || "0"}`);
            console.log(`  Calldata: ${call.calldata.substring(0, 50)}...`);
            
        });

        console.log('\n✅ Draft proposal data fetched successfully!');
        console.log('\nNext steps:');
        console.log('1. Create proposal directory: mkdir -p src/ens/proposals/ep-X-Y-draft');
        console.log('2. Copy files: cp draftCalldata.json proposalDescription.md src/ens/proposals/ep-X-Y-draft/');
        console.log('3. Create test file: calldataCheck.t.sol');

    } catch (error) {
        console.error('Error fetching draft proposal:', error.message);
        process.exit(1);
    }
}

// Check if this script is being run directly
if (require.main === module) {
    // Check if fetch is available (Node.js 18+)
    if (typeof fetch === 'undefined') {
        console.error('This script requires Node.js 18+ for fetch support, or install node-fetch package');
        process.exit(1);
    }
    
    // Get draft ID from command line arguments
    const draftId = process.argv[2];
    
    fetchDraftProposal(draftId);
}

module.exports = { fetchDraftProposal };