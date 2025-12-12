const fs = require('fs');
const path = require('path');

const TALLY_API_URL = 'https://api.tally.xyz/query';
const PROPOSAL_ID = '2746003790330071033';

const query = `
query Proposal {
    proposal(input: {id: "${PROPOSAL_ID}", isLatest: true}) {
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

async function fetchCalldata() {
    try {
        console.log('Fetching calldata from Tally API...');
        
        const response = await fetch(TALLY_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Api-Key': '365b418f59bd6dc4a0d7f23c2e8c12d982f156e9069695a6f0a2dcc3232448df'
            },
            body: JSON.stringify({ query })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        
        if (data.errors) {
            throw new Error(`GraphQL error: ${JSON.stringify(data.errors)}`);
        }

        const executableCalls = data.data.proposal.executableCalls;
        const description = data.data.proposal.metadata.description;
        
        if (!executableCalls || executableCalls.length === 0) {
            throw new Error('No executable calls found in the proposal');
        }

        console.log(`Found ${executableCalls.length} executable call(s)`);

        // Create the draft calldata structure (without description)
        const draftCalldata = {
            proposalId: "2636017379351463232",
            executableCalls: executableCalls.map(call => ({
                target: call.target,
                calldata: call.calldata,
                value: call.value || "0"
            }))
        };

        // Define output paths
        const projectRoot = path.resolve(__dirname, '../../');
        const outputDir = path.join(projectRoot, '');
        const jsonOutputPath = path.join(outputDir, 'proposalCalldata.json');
        const mdOutputPath = path.join(outputDir, 'proposalDescription.md');
        
        // Write JSON file (without description)
        fs.writeFileSync(jsonOutputPath, JSON.stringify(draftCalldata, null, 2));
        console.log(`Successfully created ${jsonOutputPath}`);
        
        // Write description as markdown file
        fs.writeFileSync(mdOutputPath, description);
        console.log(`Successfully created ${mdOutputPath}`);
        
        console.log(`Executable calls:`, executableCalls.length);
        console.log(`Description length:`, description.length);
        
        // Log each call for verification
        executableCalls.forEach((call, index) => {
            console.log(`Call ${index + 1}:`);
            console.log(`  Target: ${call.target}`);
            console.log(`  Value: ${call.value || "0"}`);
            console.log(`  Calldata: ${call.calldata.substring(0, 50)}...`);
        });

    } catch (error) {
        console.error('Error fetching calldata:', error.message);
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
    
    fetchCalldata();
}

module.exports = { fetchCalldata }; 