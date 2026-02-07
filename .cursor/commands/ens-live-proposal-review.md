New ENS proposal to review. Ask for:
- Proposal URL on Tally (to determine if it's live or draft)
- Proposal number or name (e.g., EP-6.17)

Then:
1. Check if URL contains "/draft/" → Use DRAFT_CALLDATA_REVIEW_GUIDE.md
2. Otherwise → Use CALLDATA_REVIEW_GUIDE.md for live proposals

Key differences:
- Draft: _isProposalSubmitted() returns false, use ep-title-of-proposal naming
- Live: _isProposalSubmitted() returns true, use ep-X-Y naming