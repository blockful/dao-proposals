const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const review = require('./review');

const ID = '29869795646732068004798516302146892294228731133327210892747948610417217569076';
const DRAFT = 'a9adfa71-3cde-44f5-950b-ff97602bdeef';

const CLEAN_TEST = `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract Proposal_ENS_EP_7_2_Test is ENS_Governance {
    uint256 constant expectedProposalId = 1;
    string constant url = "https://example.com";

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);
        assertGe(balance, 1);
    }

    function _afterExecution() public override {
        assertEq(balance, 1);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-7-2";
    }
}
`;
const LINT = { phase: 'live', calls: 1, dir: 'src/ens/proposals/ep-7-2' };

test('parseRef reads every proposal URL we get', () => {
    const live = (input, dao) => assert.deepStrictEqual(review.parseRef(input), { phase: 'live', dao, id: ID });
    live(`https://ens.gov.blockful.io/proposals/${ID}`, 'ens');
    live(`https://anticapture.com/ens/governance/proposal/${ID}`, 'ens');
    live(`https://www.tally.xyz/gov/uniswap/proposal/${ID}`, 'uniswap');
    live(ID, 'ens');

    const draft = (input, dao) => assert.deepStrictEqual(review.parseRef(input), { phase: 'draft', dao, id: DRAFT });
    draft(`https://ens.gov.blockful.io/proposals/new?draftId=${DRAFT}`, 'ens');
    draft(`https://app.anticapture.com/shutter/proposals/new?draftId=${DRAFT}`, 'shutter');
    draft(DRAFT, 'ens');

    assert.strictEqual(review.parseRef('https://discuss.ens.domains/t/some-topic/22475'), null);
});

test('proposal links go through the ENS governance front end', () => {
    assert.strictEqual(review.proposalLink('ens', 'live', '7'), 'https://ens.gov.blockful.io/proposals/7');
    assert.strictEqual(review.proposalLink('ens', 'draft', DRAFT), `https://ens.gov.blockful.io/proposals/new?draftId=${DRAFT}`);
    assert.strictEqual(review.proposalLink('uniswap', 'live', '7'), 'https://www.tally.xyz/gov/uniswap/proposal/7');
    assert.strictEqual(review.proposalLink('uniswap', 'draft', DRAFT), `https://app.anticapture.com/uniswap/proposals/new?draftId=${DRAFT}`);
});

test('names come from the proposal title', () => {
    assert.strictEqual(review.directoryName('ens', '[7.2] [Social] Funding Request'), 'ep-7-2');
    assert.strictEqual(review.directoryName('ens', '[EP 6.49] SPP3'), 'ep-6-49');
    assert.strictEqual(review.directoryName('ens', '[Executable] Upgrade DNSSEC oracle and registrar for the rollover'), 'ep-upgrade-dnssec-oracle-and-registrar');
    assert.strictEqual(review.contractName('ens', 'ep-7-2', 'live'), 'Proposal_ENS_EP_7_2_Test');
    assert.strictEqual(review.contractName('ens', 'ep-spp3-rfp', 'draft'), 'Proposal_ENS_EP_Spp3_Rfp_Draft_Test');
});

test('decodes a ProposalCreated event', () => {
    const word = (n) => BigInt(n).toString(16).padStart(64, '0');
    const text = Buffer.from('# hi\n').toString('hex').padEnd(64, '0');
    const call = 'a9059cbb'.padEnd(64, '0');
    const head = [7, '0x1d5460f896521ad685ea4c3f2c679ec0b6806359', 288, 352, 416, 512, 100, 200, 640].map(word).join('');
    const tail = [
        word(1) + word('0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'),
        word(1) + word(5),
        word(1) + word(32) + word(0),
        word(1) + word(32) + word(4) + call,
        word(5) + text,
    ].join('');
    const event = review.decodeProposalCreated(`0x${head}${tail}`);
    assert.strictEqual(event.id, 7n);
    assert.strictEqual(event.proposer, '0x1d5460f896521ad685ea4c3f2c679ec0b6806359');
    assert.deepStrictEqual(event.targets, ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48']);
    assert.deepStrictEqual(event.values, [5n]);
    assert.deepStrictEqual(event.signatures, ['']);
    assert.deepStrictEqual(event.calldatas, ['0xa9059cbb']);
    assert.strictEqual(event.description.toString(), '# hi\n');
});

test('a plain test passes the lint', () => {
    assert.deepStrictEqual(review.lintTest(CLEAN_TEST, LINT), []);
});

test('the lint rejects what a review must not contain', () => {
    const rejects = (source, pattern, options = LINT) => {
        const problems = review.lintTest(source, options);
        assert.ok(problems.some((p) => pattern.test(p)), `expected ${pattern}, got ${JSON.stringify(problems)}`);
    };
    rejects(CLEAN_TEST.replace('contract', '/**\n * @notice hi\n */\ncontract'), /NatSpec/);
    rejects(CLEAN_TEST.replace('uint256 constant expectedProposalId', '// a\n// b\n// c\n// d\nuint256 constant expectedProposalId'), /comment lines/);
    rejects(`${CLEAN_TEST}\n// TODO: later`, /TODO/);
    rejects(CLEAN_TEST.replace('assertEq(balance, 1);', ''), /_afterExecution\(\) checks no state/);
    rejects(CLEAN_TEST.replace('        assertGe(balance, 1);\n', ''), /_beforeProposal\(\) checks no state/);
    const withCalls = (body) => CLEAN_TEST.replace('    function _afterExecution', `    function _generateCallData() public override {\n        ${body}\n    }\n\n    function _afterExecution`);
    rejects(withCalls('calldatas[0] = hex"a9059cbb";'), /hex blob/);
    rejects(withCalls('calldatas[0] = abi.encodeWithSelector(0xa9059cbb, a);'), /hardcoded selector/);
    assert.deepStrictEqual(review.lintTest(CLEAN_TEST.replace('assertEq(balance, 1);', 'bytes x = hex"a9059cbb"; assertEq(x, x);'), LINT), []);
    rejects(CLEAN_TEST.replace('assertEq(balance, 1);', 'vm.readFile("proposalCalldata.json"); assertEq(balance, 1);'), /must not read/);
    rejects(CLEAN_TEST.replace('return true;', 'return false;'), /_isProposalSubmitted/);
    rejects(CLEAN_TEST.replace('ep-7-2"', 'ep-7-3"'), /dirPath/);
    rejects(CLEAN_TEST.replaceAll('expectedProposalId', 'x'), /pin the on-chain proposal ID/);
});

test('the PR description is one short line', () => {
    const body = review.prBody({ phase: 'live', link: 'https://ens.gov.blockful.io/proposals/7', summary: '201,559 USDC moves to the Safe.' });
    assert.strictEqual(body, 'Validates [this proposal](https://ens.gov.blockful.io/proposals/7): 201,559 USDC moves to the Safe. Calldata matches.');
    assert.ok(!body.includes('\n'));
    assert.strictEqual(review.prTitle('ens', 'src/ens/proposals/ep-7-2', 'live'), 'test(ens): validate EP 7.2 calldata');
    assert.strictEqual(review.prTitle('ens', 'src/ens/proposals/ep-foo-bar', 'draft'), 'test(ens): validate foo bar draft calldata');
    const title = '[Executable] SPP3 Marketplace RFP Award: Nomentum Labs (Grails)';
    assert.strictEqual(
        review.prTitle('ens', 'src/ens/proposals/ep-spp3-marketplace-rfp-award-nomentum', 'live', title),
        'test(ens): validate SPP3 Marketplace RFP Award: Nomentum Labs (Grails) calldata',
    );
    assert.match(review.prBody({ phase: 'draft', link: 'x', summary: 's', noActions: true }), /no actions attached/);
});

test('the forum comment is ready to paste', () => {
    const sha = '10e365df18c900628842a3f2ba06ac46832a55f0';
    const comment = review.forumComment({
        phase: 'live',
        link: 'https://ens.gov.blockful.io/proposals/7',
        summary: '201,559 USDC moves from the timelock to the Safe.',
        notes: ['This review covers the calldata only.'],
        sha,
        dir: 'src/ens/proposals/ep-7-2',
    });
    assert.match(comment, /\[live\]\(https:\/\/ens\.gov\.blockful\.io\/proposals\/7\)/);
    assert.match(comment, new RegExp(`blob/${sha}/src/ens/proposals/ep-7-2/calldataCheck\\.t\\.sol`));
    assert.match(comment, /git checkout 10e365d && npm install/);
    assert.match(comment, /cd dao-proposals/);
    assert.match(comment, /MAINNET_RPC_URL/);
    assert.match(comment, /This review covers the calldata only\./);
    assert.doesNotMatch(comment, /COMMIT_HASH|SHORT_HASH|ONCHAIN_ID|\bI\b/);

    const executed = review.forumComment({ phase: 'live', link: 'https://x/7', summary: 's', notes: [], executed: true, sha, dir: 'd' });
    assert.match(executed, /This \[proposal\]\(https:\/\/x\/7\) has already executed\./);
    assert.doesNotMatch(executed, /finally/);

    const draft = review.forumComment({ phase: 'draft', link: null, summary: 's', notes: [], noActions: true, sha, dir: 'd' });
    assert.match(draft, /no actions attached/);

    const findings = ['The 2021 registrar stays a Root controller.', 'The draft names no deployed addresses.'];
    const flagged = review.forumComment({ phase: 'draft', link: null, summary: 'two Root calls', notes: [], findings, sha, dir: 'd' });
    assert.match(flagged, /We found 2 issues to address before it goes on-chain:\n\n1\. The 2021 registrar/);
    assert.doesNotMatch(flagged, /achieves the expected outcome/);
    assert.match(review.prBody({ phase: 'draft', link: 'x', summary: 's', findings }), /It has 2 findings\.$/);
});

test('CI only counts as passed when every check finished cleanly', () => {
    assert.strictEqual(review.ciState([]).state, 'pending');
    assert.strictEqual(review.ciState(null).state, 'pending');
    assert.strictEqual(review.ciState([{ name: 'a', status: 'IN_PROGRESS', conclusion: '' }]).state, 'pending');
    assert.strictEqual(review.ciState([{ name: 'a', status: 'COMPLETED', conclusion: 'FAILURE' }]).state, 'failed');
    assert.strictEqual(review.ciState([{ context: 'a', state: 'ERROR' }]).state, 'failed');
    assert.strictEqual(review.ciState([{ name: 'a', status: 'COMPLETED', conclusion: 'SUCCESS' }, { name: 'b', status: 'COMPLETED', conclusion: 'SKIPPED' }]).state, 'passed');
});

test('live skeletons pin the proposal the way each base class expects', () => {
    const fields = { phase: 'live', proposalId: '93', block: 1, proposer: null, proposerName: null, calls: 1 };
    const ens = review.skeleton({ ...fields, daoKey: 'ens', name: 'ep-7-2', dir: 'src/ens/proposals/ep-7-2' });
    assert.match(ens, /assertEq\(proposalId, expectedProposalId\);/);
    assert.doesNotMatch(ens, /proposalId = expectedProposalId;/);

    const uni = review.skeleton({ ...fields, daoKey: 'uniswap', name: 'proposal-93', dir: 'src/uniswap/proposals/93' });
    assert.match(uni, /proposalId = expectedProposalId;/);
    assert.doesNotMatch(uni, /assertEq\(proposalId, expectedProposalId\);/);
});

test('changed files keep their full paths', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'review-status-'));
    const git = (...args) => execFileSync('git', ['-C', repo, ...args], { stdio: 'ignore' });
    const here = process.cwd();
    try {
        git('init', '-q');
        fs.mkdirSync(path.join(repo, 'src'));
        fs.writeFileSync(path.join(repo, 'src', 'a.txt'), 'a');
        fs.writeFileSync(path.join(repo, 'b.txt'), 'b');
        git('add', '.');
        git('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-qm', 'init');
        fs.writeFileSync(path.join(repo, 'src', 'a.txt'), 'changed');
        git('mv', 'b.txt', 'c.txt');
        process.chdir(repo);
        assert.deepStrictEqual(review.changedFiles().sort(), ['c.txt', 'src/a.txt']);
    } finally {
        process.chdir(here);
        fs.rmSync(repo, { recursive: true, force: true });
    }
});
