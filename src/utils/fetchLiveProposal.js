const fs = require('fs');
const path = require('path');

const TALLY_API_URL = 'https://api.tally.xyz/query';
const PROPOSAL_ID = '2779038904580310743';

const query = `
    query ProposalDetails($input: ProposalInput!, $votesInput: VotesInput!) {
  proposal(input: $input) {
    id
    onchainId
    createdAt
    block {
      number
      timestamp
    }
    start {
      ... on Block {
        number
        timestamp
      }
    }
    end {
      ... on Block {
        number
        timestamp
      }
    }
    metadata {
      description
      discourseURL
      snapshotURL
    }
    executableCalls {
      value
      target
      calldata
      signature
      type
      decodedCalldata {
        signature
        parameters {
          name
          type
          value
        }
      }
      offchaindata {
        ... on ExecutableCallSwap {
          amountIn
          fee
          buyToken {
            data {
              price
              decimals
              name
              symbol
            }
          }
          sellToken {
            data {
              price
              decimals
              name
              symbol
            }
          }
          to
          quote {
            buyAmount
            feeAmount
          }
          order {
            id
            status
            buyAmount
            address
          }
          priceChecker {
            tokenPath
            feePath
            uniPoolPath
            slippage
          }
        }
        ... on ExecutableCallRewards {
          contributorFee
          tallyFee
          recipients
        }
      }
    }
    governor {
      id
      chainId
      slug
      organization {
        metadata {
          description
        }
      }
      contracts {
        governor {
          address
          type
        }
      }
      timelockId
    }
  }
  votes(input: $votesInput) {
    nodes {
      ... on OnchainVote {
        isBridged
        voter {
          name
          picture
          address
          twitter
        }
        chainId
        reason
        type
        block {
          timestamp
        }
      }
    }
  }
}
`;

const variables = {
    input: {
        id: PROPOSAL_ID
    },
    votesInput: {
        filters: {
            proposalId: PROPOSAL_ID
        },
        sort: {
            sortBy: "amount",
            isDescending: true
        },
        page: {
            limit: 500
        }
    }
};

async function fetchLiveProposal() {
    try {
        console.log('Fetching live proposal from Tally API...');
        
        const response = await fetch(TALLY_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Api-Key': '365b418f59bd6dc4a0d7f23c2e8c12d982f156e9069695a6f0a2dcc3232448df'
            },
            body: JSON.stringify({ 
                query,
                variables 
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        
        if (data.errors) {
            throw new Error(`GraphQL error: ${JSON.stringify(data.errors)}`);
        }

        const proposal = data.data.proposal;
        const executableCalls = proposal.executableCalls;
        const description = proposal.metadata.description;
        
        if (!executableCalls || executableCalls.length === 0) {
            throw new Error('No executable calls found in the proposal');
        }

        console.log(`Found ${executableCalls.length} executable call(s)`);
        
        // Log block information
        console.log(`\nBlock Information:`);
        console.log(`  Created at block: ${proposal.block?.number} (${proposal.block?.timestamp})`);
        console.log(`  Voting start block: ${proposal.start?.number} (${proposal.start?.timestamp})`);
        console.log(`  Voting end block: ${proposal.end?.number} (${proposal.end?.timestamp})`);

        // Create the draft calldata structure (without description)
        const draftCalldata = {
            proposalId: proposal.onchainId || proposal.id,
            blockNumber: proposal.block?.number,
            votingStart: proposal.start?.number,
            votingEnd: proposal.end?.number,
            createdAt: proposal.createdAt,
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
        console.error('Error fetching live proposal:', error.message);
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
    
    fetchLiveProposal();
}

module.exports = { fetchLiveProposal };
