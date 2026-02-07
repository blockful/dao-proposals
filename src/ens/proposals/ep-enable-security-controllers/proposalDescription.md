# [Executable] Enable Root and Registrar Security Controllers

| **Status** | Draft |
| ---------- | ----- |

## Abstract

This proposal enables two break-glass security controllers:

* `RootSecurityController`, which can disable a TLD by taking ownership and clearing its resolver.
* `RegistrarSecurityController`, which can disable a .eth registrar controller.

## Motivation

At present, remediating a compromise or security vulnerability in critical parts of the ENS contracts requires a DAO vote, which takes a minimum of 9 days. This provides a significant window during which an attacker could take advantage of a vulnerability with no way to stop it. This proposal introduces two security controllers, which permit the security council to disable ENS functionality in an emergency, without granting them broad powers over the ENS system.

Enabling the `RootSecurityController` allows rapid deactivation of a compromised TLD by transferring its ownership to the controller and clearing its resolver. Enabling the `RegistrarSecurityController` allows the security council to disable problematic registrar controllers, while still retaining DAO control over the base registrar.

## Specification

### Description

Batch transaction for ENS DAO execution to enable and configure the security controllers.

### Transactions Summary

This proposal contains **2** transaction(s) to be executed by the ENS DAO Timelock.

| # | Contract       | Function          | Description                                                 |
| - | -------------- | ----------------- | ----------------------------------------------------------- |
| 1 | Root           | setController     | Enable RootSecurityController as a root controller          |
| 2 | Base Registrar | transferOwnership | Transfer registrar ownership to RegistrarSecurityController |

---

## Detailed Transaction Information

### Transaction 1: Enable RootSecurityController on Root

**Target:** Root

**Address:** `<ROOT_ADDRESS>`

**Function:** `setController`

**Parameters:**

* `address controller`: `<ROOT_SECURITY_CONTROLLER_ADDRESS>`
* `bool enabled`: `true`

**Encoded Calldata:** `<TBD>`

---

### Transaction 2: Transfer Base Registrar ownership to RegistrarSecurityController

**Target:** Base Registrar Implementation

**Address:** `<BASE_REGISTRAR_ADDRESS>`

**Function:** `transferOwnership`

**Parameters:**

* `address newOwner`: `<REGISTRAR_SECURITY_CONTROLLER_ADDRESS>`

**Encoded Calldata:** `<TBD>`

---

## Notes / Assumptions

* `RootSecurityController` and `RegistrarSecurityController` are already deployed.
* Controller ownership is already held by the DAO prior to execution.

## References

* Forum post: https://discuss.ens.domains/t/executable-enable-root-and-registrar-security-controllers/21872
* Source code: [Add RegistrarSecurityController and RootSecurityController for security council access by Arachnid · Pull Request #517 · ensdomains/ens-contracts](https://github.com/ensdomains/ens-contracts/pull/517)
