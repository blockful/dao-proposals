# [6.7] [Executable] Transfer .ceo TLD to the DNSSEC registrar
| **Status**            | Pending                                                                                                     |
| --------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Discussion Thread** | [Forum](https://discuss.ens.domains/t/temp-check-executable-transfer-ceo-tld-to-the-dnssec-registrar/20594) |

## Abstract

The .ceo TLD, formerly owned by Kred Pty, has since been acquired by XYZ. Prior to the formation of the DAO, the previous owner asked for .ceo to be delegated to a custom address so they can manage a bespoke DNS integration. The new owner has requested that this change be undone, and that ownership of .ceo be reverted to the DNSSEC registrar so owners of .ceo TLDs can use the standard integration to claim their names on ENS.

To prove ownership of .ceo and their intention that we action this request, they have set a TXT record on `_ens.nic.ceo` to the address of the DNSSEC registrar, `0xB32cB5677a7C971689228EC835800432B339bA2B`. This can be verified with the following command:

```
dig TXT _ens.nic.ceo
```

## Specification

Call `setSubnodeOwner` on the ENS `Root` contract at `0xaB528d626EC275E3faD363fF1393A41F581c5897`, passing in the keccak256 hash of `ceo` and the address of the DNSSEC registrar, `0xB32cB5677a7C971689228EC835800432B339bA2B`.