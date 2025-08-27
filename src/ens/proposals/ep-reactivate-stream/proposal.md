# [Executable] Reactivate SPP2 streams
## Abstract

This proposal reactivates the Service Provider Program Season 2 (SPP2) streams that were interrupted due to a failure in Superfluid’s autowrap system. The issue has been resolved, and Superfluid has committed to covering any liquidation fees incurred by providers during the interruption. This proposal resumes the original payment streams approved in EP 6.3 and EP 6.10, including retroactive funding for the downtime.

## Motivation

Following the Superfluid autowrap failure ([post-mortem report](https://superfluidorg.notion.site/AutoWrap-System-Failure-August-2025-24f4b6e22ae98044bad6e55f7f200e0f)), the Timelock's USDCx balance ran out, interrupting the stream from the Timelock to the [Stream Management Pod](https://etherscan.io/address/0xB162Bf7A7fD64eF32b787719335d06B2780e31D1), which also ran out of USDCx, interrupting the streams to SPs. To maintain the continuity of ENS DAO’s commitments, this proposal restarts the streams and provides retroactive funding to cover the gap period, plus an additional week of pre-funding. The auto-wrapper will be able to add USDCx and ensure smooth operations going forward.

## Specification

This executable proposal will:

1. **Approve 500,000 USDC to the USDCx contract** to allow conversion for streaming.
2. **Wrap 500,000 USDC into USDCx** to provide sufficient liquidity for operations.
3. **Transfer 400,000 USDCx to the Stream Management Pod** as retroactive payment for the interrupted period. This transfer is done in USDCx rather than USDC to maintain complete visibility and tracking of all SPP program spending within the Superfluid dashboard, ensuring transparent monitoring of stream-related transactions.
4. **Recreate the stream** from ENS Treasury to the Stream Management Pod at the previously approved rate of **0.142599440769357573 USDCx/sec** (~$4.5M/year), leaving approximately 100,000 USDCx in the Treasury for ongoing stream operations.
