# Activate ENSv2

## Abstract

This proposal activates ENSv2 on Ethereum mainnet. Once executed, it:

* freezes new `.eth` registrations on the v1 registrar;
* authorises the contracts that keep unmigrated names renewable and clean up after migrated ones;
* hands ownership of the v1 `BaseRegistrar` to a renew-only contract;
* points the Universal Resolver at a proxy that will carry the switch to v2 resolution.

Afterwards, ENS Labs will:

* run a final pre-migration sync so every live v1 name is reserved for its current owner on v2;
* open registrations on the v2 `ETHRegistrar`;
* cut resolution over to v2;
* transfer every admin role it holds over the v2 contracts to the DAO.

When that's done, the DAO controls ENSv2 just as it controls v1 today, and Labs holds no privileged role in either.

## Motivation

The ENS registry we deployed in 2017 is a single flat mapping from namehash to owner, resolver and TTL. Everything built since then - the permanent registrar, the NameWrapper, fuses, wildcard resolution, CCIP-read - has been layered on top of that mapping rather than built into it. It's held up well, but the cost shows: the NameWrapper exists largely to bolt on permissions the registry can't express, and it's the single most complex and least well understood part of ENS today.

ENSv2 replaces the flat registry with a hierarchy of registries. Every name can have its own registry for its subnames, and owners can bring their own registry and resolver implementations rather than relying on standard implementations. Permissions are fine-grained roles on each name instead of irreversible fuses, so it's possible to give a subname owner exactly the rights you intend - set a resolver but not transfer, say - without wrapping anything.

## How activation works

Activation runs in five stages, and at the end of them the DAO holds every privileged role over both v1 and v2. Only stage 2 needs a vote; every other stage either has already happened or is something Labs commits to carry out once this proposal executes.

1. **Deployment and initial pre-migration (Labs, done before this vote).** Labs has deployed the full v2 contract set to mainnet, with the v2 `ETHRegistrar` deployed but *not* authorised to register names. Labs has then reserved every active or in-grace v1 `.eth` second-level name on v2 for its current owner, via a `BatchRegistrar` that only Labs controls. Reserved names are owned by the migration controller in v2; they continue to resolve through `ENSV1Resolver`, which reads their existing v1 records. Deployed addresses and the verification script are linked under Specification.
2. **This proposal executes (DAO).** In a single atomic transaction, the DAO:
   * points the v1 `.eth` resolver at `ENSV2Resolver` and authorises the v2 reverse registrar adapters on the v1 reverse registrars;
   * approves the two current v1 `PublicResolver`s in v2's `PublicResolverSet`, so names that use them move to the v2 `PublicResolver` when they migrate;
   * approves the standalone HCA implementation in the `StandaloneHCAFactory`, so the factory can deploy HCA accounts;
   * removes every remaining controller from the v1 `BaseRegistrar`, freezing new v1 registrations;
   * authorises `ETHRenewerV1`, so names that haven't migrated yet stay renewable;
   * authorises the `Graveyard`, which holds migrated v1 tokens and reclaims v1 names once they've expired past grace;
   * transfers ownership of the v1 `BaseRegistrar` to `ETHRenewerV1`, which can renew but cannot add controllers or register names;
   * points the Universal Resolver proxy at an intermediate proxy that, for now, still serves v1 resolution.
3. **Final pre-migration sync (Labs).** Labs exports a fresh snapshot of v1 registrations taken after the freeze and re-runs pre-migration. This picks up any name registered or renewed between the first pre-migration run and the freeze.
4. **v2 goes live (Labs).** Labs revokes the `BatchRegistrar`'s roles, ending pre-migration for good; enables the two migration controllers and grants `ETHRegistrar` the right to register and renew `.eth` names. Labs asks the security council to upgrade the UniversalResolver implementation to point at UR v2. From this point, new registrations happen on v2, and resolution of every name goes through the v2 registry.
5. **Handover to the DAO (Labs).** Labs transfers every admin role it holds over v2 to the DAO timelock and renounces its own: root roles on the v2 root and `.eth` registries, the `.eth` token in the root registry, ownership of the `BatchRegistrar`s used for `.eth` and DNS suffix seeding, and admin of the intermediate Universal Resolver proxy. Labs will publish each transaction and a script that checks the deployer holds no remaining role.

The registrar, renewer and other ownable v2 contracts are deployed with the DAO timelock (`0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`) as owner from the start, and registration fees are paid to it, so nothing about revenue changes hands in stage 5. The time between stages 2 and 4 is set by how long the final sync takes; we expect it to be a few hours. During this time, registrations won’t be possible on either ENSv1 or ENSv2, but all other name operations continue as normal on ENSv1. Renewals of unmigrated names will be possible once the DAO proposal executes, via the new renewer contract.

## What changes for name owners

If you own a `.eth` name and do nothing, it keeps working. It resolves exactly as it does today, and you can keep renewing it as usual; renewing it also extends its reservation on v2. There's no deadline to migrate.

When you're ready, you can move your name to v2 using the ENS app. Wrapped names with locked permissions keep them, so any guarantees you've given to holders of your subnames carry across. Once a name has moved, it's managed on v2 from then on.

A few details worth knowing:

* **Expiry.** Your name lapses on exactly the same day on v2 as it would have on v1. v2 has a shorter grace period, 28 days rather than 90, so each name's v2 expiry is extended by 62 days to make up the difference.
* **Expired names.** Names that have already lapsed past their grace period aren't carried across, and become available for anyone to register on v2.
* **New registrations.** Between this proposal executing and v2 going live, new names can't be registered, and existing names can't be renewed.
* **Apps and integrations.** All apps and integrations need to be updated to resolve against the `UniversalResolver` to make them v2-compatible. The DevRel team have been working hard to get this done and the majority of integrations are already v2-ready.

## Risks and rollback

The v1 freeze is reversible; migrating a name is not. Until stage 4, nothing a name owner does on v2 is final, and the DAO can undo stage 2 with a further executable proposal: as owner of `ETHRenewerV1`, it can call `transferRegistrarOwnership` to hand the `BaseRegistrar` back to `RegistrarSecurityController` and then re-add the v1 controllers. Once owners start migrating, their v1 tokens are held by the `Graveyard`, which has no means of returning them.

Three things change about how v1 is protected:

* **No emergency disable on v1.** Today `RegistrarSecurityController` lets an emergency controller (`0xaA5cD05f6B62C3af58AE9c4F3F7A2aCC2Cdc2Cc7`) disable a registrar controller without a vote. Once `ETHRenewerV1` owns the `BaseRegistrar`, that path no longer applies. The only controllers left are `ETHRenewerV1`, which can only renew names already reserved on v2, and the `Graveyard`, which can only claim names that have expired past grace.
* **No v1 registrations, ever.** `ETHRenewerV1` has no function to add a controller, so v1 can't be reopened for registration without the DAO first reclaiming ownership.
* **Labs holds admin over v2 between stages 1 and 5.** That's unavoidable if Labs is to run pre-migration without a vote per batch. It's bounded by stage 5, and the v2 contracts that handle funds are owned by the DAO from deployment.

## Specification

The executable makes 15 calls, executed in order from the DAO timelock. Calls 7 to 11 remove every controller currently authorised on the v1 `BaseRegistrar`, as read from mainnet on 11 October 2026; the previous `WrappedETHRegistrarController` (`0x253553366Da8546fC250F225fe3d25d0C782303b`) is already disabled. Calls 12 and 13 must come before call 14, because the registrar's owner can't change controllers once ownership has moved to `ETHRenewerV1`.

| #  | Target                                                                                                                                              | Call                                                                          | Purpose                                                                                                   |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 1  | `RegistrarSecurityController` [0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b](https://etherscan.io/address/0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b) | `setRegistrarResolver(0x8486D32948cDeF5c24236718318c6326D5d006A9)`            | Point `.eth` at `ENSV2Resolver`                                                                           |
| 2  | `DefaultReverseRegistrar` [0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9](https://etherscan.io/address/0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9)     | `setController(0xd86E32499eCAFe9c181dd7410f93A1a9bB61ef0d, true)`             | Let `DefaultReverseRegistrarAdapter` write v1 default reverse records                                     |
| 3  | `ReverseRegistrar` [0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb](https://etherscan.io/address/0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb)            | `setController(0x349151735790269a9C14668B58D7C83b5ecb9607, true)`             | Let `ReverseRegistrarAdapter` write v1 reverse records                                                    |
| 4  | `PublicResolverSet` [0xfFCedA021CBDF20f1a66ebbef32E49d208cAbf62](https://etherscan.io/address/0xfFCedA021CBDF20f1a66ebbef32E49d208cAbf62)           | `approve(0x231b0Ee14048e9dCcD1d247744d114a4EB5E8E63, true)`                   | Mark the 2023 `PublicResolver` as a v1 public resolver, so migrated names move to the v2 `PublicResolver` |
| 5  | `PublicResolverSet`                                                                                                                                 | `approve(0xF29100983E058B709F3D539b0c765937B804AC15, true)`                   | Same, for the current v1 `PublicResolver`                                                                 |
| 6  | `StandaloneHCAFactory` [0x742bf21897a78e2C98cC5f5C5473A370a081e561](https://etherscan.io/address/0x742bf21897a78e2C98cC5f5C5473A370a081e561)        | `setImplementationApproval(0x0e03Ae22bA5F4F6af8f51AC7a6d84488Db33A98a, true)` | Approve the `StandaloneSingleOwnerHCA` implementation, so the factory can deploy HCA accounts             |
| 7  | `RegistrarSecurityController`                                                                                                                       | `removeRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547)`       | Disable current `ETHRegistrarController`                                                                  |
| 8  | `RegistrarSecurityController`                                                                                                                       | `removeRegistrarController(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401)`       | Disable `NameWrapper`                                                                                     |
| 9  | `RegistrarSecurityController`                                                                                                                       | `removeRegistrarController(0x60C7C2A24b5e86C38639Fd1586917a8FEF66a56d)`       | Disable 2020 `RegistrarMigration`                                                                         |
| 10 | `RegistrarSecurityController`                                                                                                                       | `removeRegistrarController(0xCF60916b6CB4753f58533808fA610FcbD4098Ec0)`       | Disable legacy 4-of-7 Safe                                                                                |
| 11 | `RegistrarSecurityController`                                                                                                                       | `removeRegistrarController(0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5)`       | Disable original 2020 `ETHRegistrarController`                                                            |
| 12 | `RegistrarSecurityController`                                                                                                                       | `addRegistrarController(0xDa021A2C1C2F99574D861Ef8c6fA745851BEB7F6)`          | Authorise the `Graveyard` to reclaim expired v1 names                                                     |
| 13 | `RegistrarSecurityController`                                                                                                                       | `addRegistrarController(0xE038B778b1fbF47A84018820626afc908c9C62B1)`          | Authorise `ETHRenewerV1`, keeping unmigrated names renewable                                              |
| 14 | `RegistrarSecurityController`                                                                                                                       | `transferRegistrarOwnership(0xE038B778b1fbF47A84018820626afc908c9C62B1)`      | Hand the v1 `BaseRegistrar` to `ETHRenewerV1`, locking down v1                                            |
| 15 | Universal Resolver proxy [0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe](https://etherscan.io/address/0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe)      | `upgradeTo(0xcFFd2Ae680CD110D28739a70922636B5937b022B)`                       | Route resolution via the managed proxy, which still serves the v1 `UniversalResolver`                     |

After execution, anyone can confirm the result by checking that:

* `BaseRegistrarImplementation.owner()` returns `ETHRenewerV1`;
* `BaseRegistrarImplementation.controllers()` is true for `ETHRenewerV1` and the `Graveyard`, and false for the five addresses in calls 7 to 11;
* `ENSRegistry.resolver(namehash("eth"))` returns `ENSV2Resolver`;
* `controllers()` on the `ReverseRegistrar` and `DefaultReverseRegistrar` is true for their respective adapters;
* `PublicResolverSet.includes()` is true for both v1 `PublicResolver` addresses;
* `StandaloneHCAFactory.approvedImplementations()` is true for the HCA implementation;
* the Universal Resolver proxy's `implementation()` returns the managed proxy.
