# [EP6.7] [Executable] Revoke root controller role from legacy ENS multisig

#

| **Status**            | Active                                                                                                              |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Discussion Thread** | [Forum](https://discuss.ens.domains/t/ep-6-8-executable-revoke-root-controller-role-from-legacy-ens-multisig/20644) |

## Abstract

We have identified that the legacy ENS multisig, which originally controlled ENS before the DAO was created, still has
the 'controller' role on the ENS root. This means that a majority of multisig keyholders could create or replace any ENS
TLD other than .eth. .eth is locked and cannot be modified by the DAO or anyone else.

In order to correct this oversight, this proposal revokes the legacy multisig's controller role from the root contract.

## Specification

Call `setController` on the ENS `Root` contract at `0xaB528d626EC275E3faD363fF1393A41F581c5897`, passing in the address
of the legacy multisig, `0xCF60916b6CB4753f58533808fA610FcbD4098Ec0`.
