// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { UNI_Governance } from "@uniswap/uniswap.t.sol";
import { IToken } from "@uniswap/interfaces/IToken.sol";
import { IV3Factory } from "@uniswap/interfaces/IV3Factory.sol";
import { IV2Factory } from "@uniswap/interfaces/IV2Factory.sol";
import { IV2FeeToSetter } from "@uniswap/interfaces/IV2FeeToSetter.sol";
import { IEAS } from "@uniswap/interfaces/IEAS.sol";
import { IAgreementAnchor } from "@uniswap/interfaces/IAgreementAnchor.sol";
import { ITokenJar } from "@uniswap/interfaces/ITokenJar.sol";
import { IV3FeeAdapter } from "@uniswap/interfaces/IV3FeeAdapter.sol";
import { IUNIVesting } from "@uniswap/interfaces/IUNIVesting.sol";
import { IFirepit } from "@uniswap/interfaces/IFirepit.sol";
import { console2 } from "@forge-std/src/console2.sol";

contract Proposal_UNI_93_UNIfication_Test is UNI_Governance {
    uint256 originalForkBlock;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACT ADDRESSES
    //////////////////////////////////////////////////////////////////////////*/

    // Core Uniswap contracts
    IV3Factory public constant v3Factory = IV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IV2Factory public constant v2Factory = IV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IV2FeeToSetter public constant v2FeeToSetter = IV2FeeToSetter(0x18e433c7Bf8A2E1d0197CE5d8f9AFAda1A771360);

    // EAS (Ethereum Attestation Service) - AgreementAnchor
    IEAS public constant eas = IEAS(0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587);

    // Fee infrastructure
    IV3FeeAdapter public constant v3FeeAdapter =
        IV3FeeAdapter(0x5E74C9f42EEd283bFf3744fBD1889d398d40867d);
    ITokenJar public constant tokenJar = ITokenJar(payable(0xf38521f130fcCF29dB1961597bc5d2B60F995f85));
    IUNIVesting public constant uniVester = IUNIVesting(0xCa046A83EDB78F74aE338bb5A291bF6FdAc9e1D2);
    IFirepit public constant firepit = IFirepit(0x0D5Cd355e2aBEB8fb1552F56c965B867346d6721);

    // Agreement contracts (EAS attestation recipients)
    IAgreementAnchor public constant uniswapLabsAgreement =
        IAgreementAnchor(0xC707467e7fb43Fe7Cc55264F892Dd2D7f8Fc27C8);
    IAgreementAnchor public constant hartLamburAgreement =
        IAgreementAnchor(0x33A56942Fe57f3697FE0fF52aB16cb0ba9b8eadd);
    IAgreementAnchor public constant daoJonesLlcAgreement =
        IAgreementAnchor(0xF9F85a17cC6De9150Cd139f64b127976a1dE91D1);

    // AgreementAnchor recipients
    address public constant uniswapLabsWallet = 0x7A36852A428513221555aeC720a09eCd83818310;
    address public constant hartLamburWallet = 0xD1F55571cbB04139716a9a5076Aa69626B6df009;
    address public constant daoJonesLlcWallet = 0x5018e04241D2739E65919fa9B4826C79044e13e2;

    // Burn address
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    /*//////////////////////////////////////////////////////////////////////////
                                   PROPOSAL CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // UNI amounts
    uint256 public constant uniBurnAmount = 100_000_000 ether; // 100M UNI
    uint256 public constant uniVestingAmount = 40_000_000 ether; // 40M UNI
    uint256 public constant firepitThreshold = 4000 * 1e18; // 4000 UNI

    // EAS Schema UID for agreements
    bytes32 public constant agreementSchema =
        0x504f10498bcdb19d4960412dbade6fa1530b8eed65c319f15cbe20fadafe56bd;

    // Document hashes
    bytes32 public constant uniswapLabsAgreementHash =
        0xb7a5a04f613e49ce4a8c2fb142a37c6781bda05c62d46a782f36bb6e97068d3b;
    bytes32 public constant hartLamburIndemnificationHash =
        0x96861f436ef11b12dc8df810ab733ea8c7ea16cad6fd476942075ec28d5cf18a;
    bytes32 public constant daoJonesIndemnificationHash =
        0x576613b871f61f21e14a7caf5970cb9e472e82f993e10e13e2d995703471f011;

    /*//////////////////////////////////////////////////////////////////////////
                                   STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    // Before state
    uint256 deadAddressBalanceBefore;
    uint256 timelockUniBalanceBefore;
    address v3FactoryOwnerBefore;
    address v2FactoryFeeToBefore;
    address v2FactoryFeeToSetterBefore;
    uint256 vesterAllowanceBefore;

    // After state
    uint256 deadAddressBalanceAfter;
    uint256 vesterAllowanceAfter;

    /*//////////////////////////////////////////////////////////////////////////
                                   SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function _selectFork() public override {
        // Fork after proposal submission (submitted at block 24038076)
        originalForkBlock = vm.createSelectFork({ blockNumber: 24_038_100, urlOrAlias: "mainnet" });
    }

    function _beforeProposal() public override {
        // Record balances before
        deadAddressBalanceBefore = uniToken.balanceOf(deadAddress);
        timelockUniBalanceBefore = uniToken.balanceOf(address(timelock));

        // Record factory states before
        v3FactoryOwnerBefore = v3Factory.owner();
        assertEq(v3FactoryOwnerBefore, address(timelock), "V3 Factory owner should be timelock");

        v2FactoryFeeToBefore = v2Factory.feeTo();
        assertEq(v2FactoryFeeToBefore, address(0x0), "V2 Factory feeTo should be 0x0");

        v2FactoryFeeToSetterBefore = v2Factory.feeToSetter();
        assertEq(v2FactoryFeeToSetterBefore, address(v2FeeToSetter), "V2 Factory feeToSetter should be v2FeeToSetter");

        // v3 fee adapter
        address v3FeeAdapterOwner = v3FeeAdapter.owner();
        assertEq(v3FeeAdapterOwner, address(timelock), "V3 Fee Adapter owner should be timelock");
        
        address v3FeeAdapterFeeSetter = v3FeeAdapter.feeSetter();
        assertEq(v3FeeAdapterFeeSetter, address(timelock), "V3 Fee Adapter fee setter should be timelock");

        address v3FeeAdapterFactory = v3FeeAdapter.FACTORY();
        assertEq(v3FeeAdapterFactory, address(v3Factory), "V3 Fee Adapter factory should be v3Factory");

        address v3FeeAdapterTokenJar = v3FeeAdapter.TOKEN_JAR();
        assertEq(v3FeeAdapterTokenJar, address(tokenJar), "V3 Fee Adapter token jar should be tokenJar");

        // token jar
        address tokenJarOwner = tokenJar.owner();  
        assertEq(tokenJarOwner, address(timelock), "TokenJar owner should be timelock");
    
        address tokenJarReleaser = tokenJar.releaser();
        assertEq(tokenJarReleaser, address(firepit), "TokenJar releaser should be Firepit");
        
        //firepit
        address firepitOwner = firepit.owner();
        assertEq(firepitOwner, address(timelock), "Firepit owner should be timelock");
        
        address firepitThresholdSetter = firepit.thresholdSetter();
        assertEq(firepitThresholdSetter, address(timelock), "Firepit threshold setter should be timelock");

        uint256 firepitThreshold = firepit.threshold();
        assertEq(firepitThreshold, firepitThreshold, "Firepit threshold should be 4000 UNI");

        address firepitResource = firepit.RESOURCE();
        assertEq(firepitResource, address(uniToken), "Firepit resource should be uniToken");

        address firepitResourceRecipient = firepit.RESOURCE_RECIPIENT();
        assertEq(firepitResourceRecipient, deadAddress, "Firepit resource recipient should be deadAddress");

        // Record allowance before
        vesterAllowanceBefore = uniToken.allowance(address(timelock), address(uniVester));


        // Agreements signed
        vm.createSelectFork({ blockNumber: 24_064_480, urlOrAlias: "mainnet" });

        // Uniswap Labs agreement
        address uniswapLabsAgreementPartyA = uniswapLabsAgreement.PARTY_A();
        assertEq(uniswapLabsAgreementPartyA, address(timelock), "Uniswap Labs agreement party A should be timelock");
        bytes32 uniswapLabsAgreementSignaturePartyA = uniswapLabsAgreement.partyA_attestationUID();
        assertEq(uniswapLabsAgreementSignaturePartyA, bytes32(0), "Uniswap Labs agreement signature party A should be 0");
        
        address uniswapLabsAgreementPartyB = uniswapLabsAgreement.PARTY_B();
        assertEq(uniswapLabsAgreementPartyB, uniswapLabsWallet, "Uniswap Labs agreement party B should be uniswapLabsWallet");
        bytes32 uniswapLabsAgreementSignaturePartyB = uniswapLabsAgreement.partyB_attestationUID();
        assertEq(uniswapLabsAgreementSignaturePartyB, bytes32(0), "Uniswap Labs agreement signature party B should be 0");

        // Hart Lambur agreement
        address hartLamburAgreementPartyA = hartLamburAgreement.PARTY_A();
        assertEq(hartLamburAgreementPartyA, address(timelock), "Hart Lambur agreement party A should be timelock");
        bytes32 hartLamburAgreementSignaturePartyA = hartLamburAgreement.partyA_attestationUID();
        assertEq(hartLamburAgreementSignaturePartyA, bytes32(0), "Hart Lambur agreement signature party A should be 0");
        
        address hartLamburAgreementPartyB = hartLamburAgreement.PARTY_B();
        assertEq(hartLamburAgreementPartyB, hartLamburWallet, "Hart Lambur agreement party B should be hartLamburWallet");
        
        bytes32 hartLamburAgreementSignaturePartyB = hartLamburAgreement.partyB_attestationUID();
        assertNotEq(hartLamburAgreementSignaturePartyB, bytes32(0), "Hart Lambur agreement signature party B should not be 0");

        // DAO Jones LLC agreement
        address daoJonesLlcAgreementPartyA = daoJonesLlcAgreement.PARTY_A();
        assertEq(daoJonesLlcAgreementPartyA, address(timelock), "DAO Jones LLC agreement party A should be timelock");
        bytes32 daoJonesLlcAgreementSignaturePartyA = daoJonesLlcAgreement.partyA_attestationUID();
        assertEq(daoJonesLlcAgreementSignaturePartyA, bytes32(0), "DAO Jones LLC agreement signature party A should be 0");
        
        address daoJonesLlcAgreementPartyB = daoJonesLlcAgreement.PARTY_B();
        assertEq(daoJonesLlcAgreementPartyB, daoJonesLlcWallet, "DAO Jones LLC agreement party B should be daoJonesLlcWallet");
        bytes32 daoJonesLlcAgreementSignaturePartyB = daoJonesLlcAgreement.partyB_attestationUID();
        assertEq(daoJonesLlcAgreementSignaturePartyB, bytes32(0), "DAO Jones LLC agreement signature party B should be 0");

        vm.selectFork(originalForkBlock);   
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   CALLDATA GENERATION
    //////////////////////////////////////////////////////////////////////////*/

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 8;
        proposalId = 93;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 0. AgreementAnchor.attest - DAO Jones LLC indemnification
        targets[0] = address(eas);
        calldatas[0] = _buildAttestCalldata(address(daoJonesLlcAgreement), daoJonesIndemnificationHash);
        values[0] = 0;
        signatures[0] = "";

        // 1. UNI.transfer - Burn 100M UNI to dead address
        targets[1] = address(uniToken);
        calldatas[1] = abi.encodeWithSelector(IToken.transfer.selector, deadAddress, uniBurnAmount);
        values[1] = 0;
        signatures[1] = "";

        // 2. v3Factory.setOwner - Set owner to v3FeeAdapter
        targets[2] = address(v3Factory);
        calldatas[2] = abi.encodeWithSelector(IV3Factory.setOwner.selector, address(v3FeeAdapter));
        values[2] = 0;
        signatures[2] = "";

        // 3. V2FeeToSetter.setFeeToSetter - Set feeToSetter to Timelock
        targets[3] = address(v2FeeToSetter);
        calldatas[3] = abi.encodeWithSelector(IV2FeeToSetter.setFeeToSetter.selector, address(timelock));
        values[3] = 0;
        signatures[3] = "";

        // 4. v2Factory.setFeeTo - Set feeTo to TokenJar
        targets[4] = address(v2Factory);
        calldatas[4] = abi.encodeWithSelector(IV2Factory.setFeeTo.selector, address(tokenJar));
        values[4] = 0;
        signatures[4] = "";

        // 5. UNI.approve - Approve 40M UNI to UNIVester
        targets[5] = address(uniToken);
        calldatas[5] = abi.encodeWithSelector(IToken.approve.selector, address(uniVester), uniVestingAmount);
        values[5] = 0;
        signatures[5] = "";

        // 6. AgreementAnchor.attest - Uniswap Labs services agreement
        targets[6] = address(eas);
        calldatas[6] = _buildAttestCalldata(address(uniswapLabsAgreement), uniswapLabsAgreementHash);
        values[6] = 0;
        signatures[6] = "";

        // 7. AgreementAnchor.attest - Hart Lambur indemnification
        targets[7] = address(eas);
        calldatas[7] = _buildAttestCalldata(address(hartLamburAgreement), hartLamburIndemnificationHash);
        values[7] = 0;
        signatures[7] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    /// @notice Builds the calldata for EAS attest function
    /// @dev The EAS attest function takes an AttestationRequest struct
    function _buildAttestCalldata(address recipient, bytes32 documentHash) internal pure returns (bytes memory) {
        // Build AttestationRequestData
        IEAS.AttestationRequestData memory data = IEAS.AttestationRequestData({
            recipient: recipient,
            expirationTime: 0, // No expiration
            revocable: false, // Not revocable
            refUID: bytes32(0), // No reference
            data: abi.encode(documentHash), // Document hash as data
            value: 0 // No ETH value
        });

        // Build AttestationRequest
        IEAS.AttestationRequest memory request = IEAS.AttestationRequest({
            schema: agreementSchema,
            data: data
        });

        return abi.encodeWithSelector(IEAS.attest.selector, request);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   ASSERTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _afterExecution() public override {
        // 1. Verify 100M UNI was burned
        deadAddressBalanceAfter = uniToken.balanceOf(deadAddress);
        assertEq(
            deadAddressBalanceAfter,
            deadAddressBalanceBefore + uniBurnAmount,
            "Dead address should receive 100M UNI"
        );

        // 2. Verify V3 Factory owner changed
        address v3OwnerAfter = v3Factory.owner();
        assertEq(v3OwnerAfter, address(v3FeeAdapter), "V3 Factory owner should be v3FeeAdapter");

        // 3. Verify V2 Factory feeTo changed
        address v2FeeToAfter = v2Factory.feeTo();
        assertEq(v2FeeToAfter, address(tokenJar), "V2 Factory feeTo should be TokenJar");

        // // 4. Verify V2 Factory feeToSetter changed
        address v2FeeToSetterAfter = v2Factory.feeToSetter();
        assertEq(v2FeeToSetterAfter, address(timelock), "V2 Factory feeToSetter should be Timelock");

        // 5. Verify UNI approval for vesting
        vesterAllowanceAfter = uniToken.allowance(address(timelock), address(uniVester));
        assertEq(vesterAllowanceAfter, uniVestingAmount, "UNI Vester allowance should be 40M");

        // 6. Verify agreements signatures
        bytes32 uniswapLabsAgreementSignaturePartyA = uniswapLabsAgreement.partyA_attestationUID();
        assertNotEq(uniswapLabsAgreementSignaturePartyA, bytes32(0), "Uniswap Labs agreement signature party A should not be 0");
        
        bytes32 hartLamburAgreementSignaturePartyA = hartLamburAgreement.partyA_attestationUID();
        assertNotEq(hartLamburAgreementSignaturePartyA, bytes32(0), "Hart Lambur agreement signature party A should not be 0");
        
        bytes32 daoJonesLlcAgreementSignaturePartyA = daoJonesLlcAgreement.partyA_attestationUID();
        assertNotEq(daoJonesLlcAgreementSignaturePartyA, bytes32(0), "DAO Jones LLC agreement signature party A should not be 0");

        // test uni vester
        vm.warp(1_767_225_600); //  January 1, 2026 12:00:00 AM 
        uint256 timelockBalanceBefore = uniToken.balanceOf(address(timelock));
        uniVester.withdraw();
        uint256 timelockBalanceAfter = uniToken.balanceOf(address(timelock));
        assertEq(
            timelockBalanceBefore - timelockBalanceAfter,
            uniVester.quarterlyVestingAmount(),
            "Timelock should receive 5M UNI"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PROPOSAL STATUS
    //////////////////////////////////////////////////////////////////////////*/

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Proposal 93 is already submitted on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/uniswap/proposals/93 - UNIfication";
    }
}

