#!/usr/bin/env node
/**
 * decodeMultiSend.js — Decode a Zodiac MultiSend hex blob into structured transactions
 *
 * Usage:
 *   node src/utils/decodeMultiSend.js <solidity-file>
 *
 * Extracts the hex blob from _getSafeCalldata(), parses MultiSend transactions,
 * decodes Zodiac Roles Modifier calls, and generates Solidity reconstruction code.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ─── Known Selectors ─────────────────────────────────────────────────────────

const ZODIAC_SELECTORS = {
  "0c6c76b8": { name: "scopeTarget", sig: "scopeTarget(bytes32,address)" },
  "0172a43a": { name: "revokeTarget", sig: "revokeTarget(bytes32,address)" },
  "66523f7d": {
    name: "revokeFunction",
    sig: "revokeFunction(bytes32,address,bytes4)",
  },
  "7508dd98": {
    name: "scopeFunction",
    sig: "scopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)",
  },
  b3dd25c7: {
    name: "allowFunction",
    sig: "allowFunction(bytes32,address,bytes4,uint8)",
  },
  "7b0da5b2": {
    name: "allowTarget",
    sig: "allowTarget(bytes32,address,uint8)",
  },
  "2916a9af": {
    name: "setTransactionUnwrapper",
    sig: "setTransactionUnwrapper(address,bytes4,address)",
  },
};

// Known function selectors for identification
const KNOWN_SELECTORS = {
  "095ea7b3": "approve(address,uint256)",
  a9059cbb: "transfer(address,uint256)",
  "23b872dd": "transferFrom(address,address,uint256)",
  "8d80ff0a": "multiSend(bytes)",
  "6a761202": "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
  "0ae1b13d": "post(string,string)",
};

// ─── Hex Utilities ───────────────────────────────────────────────────────────

function hexToBytes(hex) {
  hex = hex.replace(/^0x/, "");
  const bytes = [];
  for (let i = 0; i < hex.length; i += 2) {
    bytes.push(parseInt(hex.substr(i, 2), 16));
  }
  return Buffer.from(bytes);
}

function readUint8(buf, offset) {
  return buf[offset];
}

function readAddress(buf, offset) {
  return (
    "0x" +
    buf
      .slice(offset, offset + 20)
      .toString("hex")
      .replace(/^0{24}/, "")
  );
}

function readAddressFull(buf, offset) {
  return "0x" + buf.slice(offset, offset + 20).toString("hex");
}

function readBytes32(buf, offset) {
  return "0x" + buf.slice(offset, offset + 32).toString("hex");
}

function readUint256(buf, offset) {
  return BigInt("0x" + buf.slice(offset, offset + 32).toString("hex"));
}

function readBytes4(buf, offset) {
  return buf.slice(offset, offset + 4).toString("hex");
}

function checksumAddress(addr) {
  // Use cast to get checksum address
  try {
    return execSync(`cast to-check-sum-address ${addr}`, {
      encoding: "utf-8",
    }).trim();
  } catch {
    return addr;
  }
}

// ─── MultiSend Parser ────────────────────────────────────────────────────────

function parseMultiSendPayload(hex) {
  const buf = hexToBytes(hex);
  let offset = 0;

  // Check for multiSend selector (0x8d80ff0a)
  const selector = buf.slice(0, 4).toString("hex");
  if (selector === "8d80ff0a") {
    // Skip selector (4) + offset to bytes (32) + bytes length (32)
    const bytesOffset = Number(readUint256(buf, 4));
    const bytesLength = Number(readUint256(buf, 4 + bytesOffset));
    offset = 4 + bytesOffset + 32;
    return parsePackedTransactions(buf, offset, offset + bytesLength);
  }

  // Raw packed transactions (no selector wrapper)
  return parsePackedTransactions(buf, 0, buf.length);
}

function parsePackedTransactions(buf, start, end) {
  const transactions = [];
  let offset = start;

  while (offset < end) {
    const operation = readUint8(buf, offset);
    offset += 1;

    const to = readAddressFull(buf, offset);
    offset += 20;

    const value = readUint256(buf, offset);
    offset += 32;

    const dataLength = Number(readUint256(buf, offset));
    offset += 32;

    const data = buf.slice(offset, offset + dataLength).toString("hex");
    offset += dataLength;

    transactions.push({
      operation, // 0 = Call, 1 = DelegateCall
      to: checksumAddress(to),
      value,
      data,
      dataLength,
    });
  }

  return transactions;
}

// ─── ABI Decoder ─────────────────────────────────────────────────────────────

function decodeTransaction(tx) {
  if (tx.dataLength < 4) {
    return { ...tx, decoded: null, functionName: "raw" };
  }

  const selector = tx.data.slice(0, 8);
  const calldata = tx.data.slice(8);

  // Check if it's a known Zodiac Roles call
  const zodiac = ZODIAC_SELECTORS[selector];
  if (zodiac) {
    try {
      const decoded = decodeZodiacCall(zodiac.name, calldata);
      return { ...tx, selector, decoded, functionName: zodiac.name };
    } catch (e) {
      return {
        ...tx,
        selector,
        decoded: null,
        functionName: zodiac.name,
        error: e.message,
      };
    }
  }

  // Try to identify the selector
  const known = KNOWN_SELECTORS[selector];
  return {
    ...tx,
    selector,
    decoded: null,
    functionName: known || `unknown_${selector}`,
  };
}

function decodeZodiacCall(name, calldataHex) {
  const buf = hexToBytes(calldataHex);

  switch (name) {
    case "scopeTarget":
      return {
        roleKey: readBytes32(buf, 0),
        targetAddress: checksumAddress(
          "0x" + readBytes32(buf, 32).slice(26)
        ),
      };

    case "revokeTarget":
      return {
        roleKey: readBytes32(buf, 0),
        targetAddress: checksumAddress(
          "0x" + readBytes32(buf, 32).slice(26)
        ),
      };

    case "revokeFunction":
      return {
        roleKey: readBytes32(buf, 0),
        targetAddress: checksumAddress(
          "0x" + readBytes32(buf, 32).slice(26)
        ),
        selector: "0x" + readBytes32(buf, 64).slice(2, 10),
      };

    case "allowFunction":
      return {
        roleKey: readBytes32(buf, 0),
        targetAddress: checksumAddress(
          "0x" + readBytes32(buf, 32).slice(26)
        ),
        selector: "0x" + readBytes32(buf, 64).slice(2, 10),
        options: Number(readUint256(buf, 96)),
      };

    case "allowTarget":
      return {
        roleKey: readBytes32(buf, 0),
        targetAddress: checksumAddress(
          "0x" + readBytes32(buf, 32).slice(26)
        ),
        options: Number(readUint256(buf, 64)),
      };

    case "scopeFunction":
      return decodeScopeFunction(buf);

    case "setTransactionUnwrapper":
      return {
        handler: checksumAddress("0x" + readBytes32(buf, 0).slice(26)),
        selector: "0x" + readBytes32(buf, 32).slice(2, 10),
        adapter: checksumAddress("0x" + readBytes32(buf, 64).slice(26)),
      };

    default:
      return null;
  }
}

function decodeScopeFunction(buf) {
  const roleKey = readBytes32(buf, 0);
  const targetAddress = checksumAddress(
    "0x" + readBytes32(buf, 32).slice(26)
  );
  const selector = "0x" + readBytes32(buf, 64).slice(2, 10);
  const conditionsOffset = Number(readUint256(buf, 96));
  const options = Number(readUint256(buf, 128));

  // Decode ConditionFlat[] at the offset
  const conditions = decodeConditionFlatArray(buf, conditionsOffset + 0);

  return { roleKey, targetAddress, selector, conditions, options };
}

function decodeConditionFlatArray(buf, baseOffset) {
  // baseOffset points to the start of the array encoding
  // First 32 bytes: array length
  const length = Number(readUint256(buf, baseOffset));
  const conditions = [];

  // Next: N offsets to each struct
  const structOffsets = [];
  for (let i = 0; i < length; i++) {
    structOffsets.push(
      Number(readUint256(buf, baseOffset + 32 + i * 32))
    );
  }

  // Decode each struct
  for (let i = 0; i < length; i++) {
    const structStart = baseOffset + 32 + structOffsets[i];
    const parent = Number(readUint256(buf, structStart));
    const paramType = Number(readUint256(buf, structStart + 32));
    const operator = Number(readUint256(buf, structStart + 64));
    // compValue is a dynamic bytes field
    const compValueOffset = Number(readUint256(buf, structStart + 96));
    const compValueStart = structStart + compValueOffset;
    const compValueLength = Number(readUint256(buf, compValueStart));
    const compValue =
      compValueLength > 0
        ? "0x" +
          buf
            .slice(compValueStart + 32, compValueStart + 32 + compValueLength)
            .toString("hex")
        : "";

    conditions.push({ parent, paramType, operator, compValue });
  }

  return conditions;
}

// ─── Solidity Code Generator ─────────────────────────────────────────────────

const PARAM_TYPE_NAMES = {
  0: "PARAM_TYPE_NONE",
  1: "PARAM_TYPE_STATIC",
  2: "PARAM_TYPE_DYNAMIC",
  3: "PARAM_TYPE_TUPLE",
  5: "PARAM_TYPE_CALLDATA",
};

const OPERATOR_NAMES = {
  0: "OP_PASS",
  2: "OP_OR",
  5: "OP_MATCHES",
  15: "OP_EQUAL_TO_AVATAR",
  16: "OP_EQUAL_TO",
};

const EXEC_OPTION_NAMES = {
  0: "EXEC_NONE",
  1: "EXEC_SEND",
  2: "EXEC_DELEGATE_CALL",
};

function generateSolidityForTransaction(tx, index) {
  const dec = tx.decoded;
  if (!dec) {
    return `        // TX ${index}: ${tx.functionName} on ${tx.to} — RAW (could not decode)\n        // data: 0x${tx.data.slice(0, 80)}...\n`;
  }

  switch (tx.functionName) {
    case "scopeTarget":
      return `        // TX ${index}: scopeTarget — ${dec.targetAddress}\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ${dec.targetAddress}))`;

    case "revokeTarget":
      return `        // TX ${index}: revokeTarget — ${dec.targetAddress}\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, ${dec.targetAddress}))`;

    case "revokeFunction":
      return `        // TX ${index}: revokeFunction — ${dec.targetAddress} ${dec.selector}\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, ${dec.targetAddress}, bytes4(${dec.selector})))`;

    case "allowFunction":
      return `        // TX ${index}: allowFunction — ${dec.targetAddress} ${dec.selector}\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, ${dec.targetAddress}, bytes4(${dec.selector}), ${EXEC_OPTION_NAMES[dec.options] || dec.options}))`;

    case "allowTarget":
      return `        // TX ${index}: allowTarget — ${dec.targetAddress}\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowTarget.selector, MANAGER_ROLE, ${dec.targetAddress}, ${EXEC_OPTION_NAMES[dec.options] || dec.options}))`;

    case "scopeFunction":
      return generateScopeFunctionCode(tx, index);

    case "setTransactionUnwrapper":
      return `        // TX ${index}: setTransactionUnwrapper\n` +
        `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.setTransactionUnwrapper.selector, ${dec.handler}, bytes4(${dec.selector}), ${dec.adapter}))`;

    default:
      return `        // TX ${index}: ${tx.functionName} — needs manual review\n`;
  }
}

function generateScopeFunctionCode(tx, index) {
  const dec = tx.decoded;
  const condFuncName = `_conditions_tx${index}`;

  let code = `        // TX ${index}: scopeFunction — ${dec.targetAddress} selector ${dec.selector}\n`;
  code += `        _packTx(address(ROLES_MOD), abi.encodeWithSelector(\n`;
  code += `            IRolesModifier.scopeFunction.selector, MANAGER_ROLE, ${dec.targetAddress}, bytes4(${dec.selector}),\n`;
  code += `            ${condFuncName}(), ${EXEC_OPTION_NAMES[dec.options] || dec.options}\n`;
  code += `        ))`;

  return { packCode: code, conditionsFunc: generateConditionsFunction(condFuncName, dec.conditions) };
}

function generateConditionsFunction(name, conditions) {
  let code = `    function ${name}() internal pure returns (ConditionFlat[] memory c) {\n`;
  code += `        c = new ConditionFlat[](${conditions.length});\n`;

  for (let i = 0; i < conditions.length; i++) {
    const cond = conditions[i];
    const paramType = PARAM_TYPE_NAMES[cond.paramType] || String(cond.paramType);
    const operator = OPERATOR_NAMES[cond.operator] || String(cond.operator);
    const compValue = cond.compValue
      ? `hex"${cond.compValue.replace(/^0x/, "")}"`
      : '""';

    code += `        c[${i}] = ConditionFlat(${cond.parent}, ${paramType}, ${operator}, ${compValue});\n`;
  }

  code += `    }\n`;
  return code;
}

// ─── Hex Blob Extractor ──────────────────────────────────────────────────────

function extractHexBlob(filePath) {
  const content = fs.readFileSync(filePath, "utf-8");

  // Find _getSafeCalldata function and extract the hex blob
  const match = content.match(
    /function\s+_getSafeCalldata\s*\(\s*\)[^{]*\{[^}]*?hex"([0-9a-fA-F]+)"/s
  );

  if (match) {
    return match[1];
  }

  // Try to find any large hex blob
  const hexMatch = content.match(/hex"([0-9a-fA-F]{1000,})"/);
  if (hexMatch) {
    return hexMatch[1];
  }

  throw new Error("No hex blob found in " + filePath);
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
  const filePath = process.argv[2];
  if (!filePath) {
    console.error("Usage: node decodeMultiSend.js <solidity-file>");
    process.exit(1);
  }

  const outputDir = process.argv[3] || path.dirname(filePath);
  const hex = extractHexBlob(filePath);

  console.log(`Extracted hex blob: ${hex.length} chars (${hex.length / 2} bytes)`);

  // Parse the MultiSend payload
  const transactions = parseMultiSendPayload(hex);
  console.log(`Found ${transactions.length} packed transactions\n`);

  // Decode each transaction
  const decoded = transactions.map((tx, i) => {
    const result = decodeTransaction(tx);
    return result;
  });

  // Generate summary
  const summary = [];
  const conditionsFunctions = [];
  const packLines = [];

  for (let i = 0; i < decoded.length; i++) {
    const tx = decoded[i];
    const idx = i + 1;

    summary.push(
      `TX ${idx}: ${tx.functionName} → ${tx.to}${tx.decoded?.targetAddress ? ` (target: ${tx.decoded.targetAddress})` : ""}${tx.decoded?.selector ? ` sel: ${tx.decoded.selector}` : ""}`
    );

    const solCode = generateSolidityForTransaction(tx, idx);

    if (typeof solCode === "object") {
      // scopeFunction returns both pack code and conditions function
      packLines.push(solCode.packCode);
      conditionsFunctions.push(solCode.conditionsFunc);
    } else {
      packLines.push(solCode);
    }
  }

  // Write summary
  console.log("=== TRANSACTION SUMMARY ===\n");
  summary.forEach((s) => console.log(s));

  // Write decoded JSON
  const jsonPath = path.join(outputDir, "decoded_transactions.json");
  fs.writeFileSync(
    jsonPath,
    JSON.stringify(
      decoded.map((tx, i) => ({
        index: i + 1,
        operation: tx.operation,
        to: tx.to,
        functionName: tx.functionName,
        decoded: tx.decoded,
        error: tx.error,
      })),
      (key, value) => (typeof value === "bigint" ? value.toString() : value),
      2
    )
  );
  console.log(`\nWrote decoded transactions to ${jsonPath}`);

  // Write Solidity pack functions
  const solPath = path.join(outputDir, "generated_pack_code.sol.txt");
  let solCode = "// AUTO-GENERATED by decodeMultiSend.js — review and integrate\n\n";
  solCode += "    // ─── Packed Transactions ──────────────────────────────────────\n\n";
  solCode += "    function _buildPackedTransactions() internal pure returns (bytes memory) {\n";
  solCode += "        return abi.encodePacked(\n";
  solCode += packLines.map(l => l.replace(/^        /, "            ")).join(",\n");
  solCode += "\n        );\n    }\n\n";

  if (conditionsFunctions.length > 0) {
    solCode += "    // ─── Condition Builders ──────────────────────────────────────\n\n";
    solCode += conditionsFunctions.join("\n");
  }

  fs.writeFileSync(solPath, solCode);
  console.log(`Wrote generated Solidity to ${solPath}`);

  // Write address registry (unique addresses referenced)
  const addresses = new Set();
  decoded.forEach((tx) => {
    addresses.add(tx.to);
    if (tx.decoded?.targetAddress) addresses.add(tx.decoded.targetAddress);
    if (tx.decoded?.handler) addresses.add(tx.decoded.handler);
    if (tx.decoded?.adapter) addresses.add(tx.decoded.adapter);
    // Extract addresses from condition compValues
    if (tx.decoded?.conditions) {
      tx.decoded.conditions.forEach((c) => {
        if (c.compValue && c.compValue.length === 66) {
          // 32 bytes = possibly a padded address
          const possibleAddr = "0x" + c.compValue.slice(26);
          if (possibleAddr !== "0x" + "0".repeat(40)) {
            addresses.add(checksumAddress(possibleAddr));
          }
        }
      });
    }
  });

  const addrPath = path.join(outputDir, "decoded_addresses.txt");
  fs.writeFileSync(addrPath, [...addresses].sort().join("\n") + "\n");
  console.log(`Wrote ${addresses.size} unique addresses to ${addrPath}`);
}

main();
