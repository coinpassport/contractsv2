# Coinpassport V2 Contracts

Foundry repository for the contracts for Coinpassport V2 which tokenizes your passport into an NFT privately using a [Semaphore Group](https://semaphore.pse.dev/).

## Regular epochs

Every ~8 weeks<sup>1</sup>, a new epoch will begin. Each user must join the new group associated with the new epoch.

As a consequence:

* Expired passports deactivate without revealing their expiration date (especially since you don't have to join all epochs)
* ZK proof generation time is minimized because the merkle tree only contains active users within the epoch instead of all-time active users
* Provides users a chance to reinvent their anonymous persona each epoch (i.e. if you get doxxed, you can start over at the next epoch)
    * Also minimizes anonymity penalties facing early adopters

I [investigated proving an EdDSA signature verification using circom](https://github.com/coinpassport/contractsv2/commit/e1477e5533283933dd7dd05cae23b1e474966bc8) but was unable to figure out a way to protect against replay attacks without allowing a malicious server host of this application to break the anonymity. This approach would require publicly revealing the expiration date, (a fuzzed version of it anyways) reducing privacy for a slight UX simplification. For these reasons, requring users to join each new group has been implemented.

---

<sup>1</sup>too short and it's too much rejoining, too long and expirations lag

## Deploy

`VerificationV2` to Holesky:

```shell
$ SIGNER=0x182dA9ECA9234A4c67E2355534c368e707DF8911 \
SEMAPHORE=0x05D816D46cF7A39600648cA040e94678b8342277 \
FEE_TOKEN=0x925556a61d27e2e30e9e3a2eb45feedfd2003801 \
GROUP_ID=5 \
GROUP_DEPTH=16 \
forge script script/VerificationV2.s.sol:Deploy --rpc-url https://ethereum-holesky.publicnode.com/ --broadcast --verify -vvvv
```

`DummyERC20` to Holesky:

```shell
$ forge script script/DummyERC20.s.sol:Deploy --rpc-url https://ethereum-holesky.publicnode.com/ --broadcast --verify -vvvv
```

`FeeERC20` to Holesky:

```shell
$ COLLECTOR=0x0000000000000000000000000000000000000000 \
PAY_TOKEN=0x61BA23E3584EFCD67d3b265bfe7bAf0fE3da791D \
PAY_AMOUNT=10 \
FEE_RECIPIENT=0xa48c718AE6dE6599c5A46Fd6caBff54Def39473a \
forge script script/FeeERC20.s.sol:Deploy --rpc-url https://ethereum-holesky.publicnode.com/ --broadcast --verify -vvvv
```

> Update the `collector` setting using `setCollector` function after deploying `VerificationV2` since it's a circular reference.

## License

MIT
