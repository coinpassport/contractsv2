# Coinpassport V2 Contracts

Foundry repository for the contracts for Coinpassport V2 which tokenizes your passport into an NFT privately using a [Semaphore Group](https://semaphore.pse.dev/).


## Deploy

Example for Holesky:

```shell
$ SIGNER=0x182dA9ECA9234A4c67E2355534c368e707DF8911 \
SEMAPHORE=0x05D816D46cF7A39600648cA040e94678b8342277 \
GROUP_ID=2 \
FEE_TOKEN=0xEd01f84287b97C5793421F4BD7bDed1CAaCBBA58 \
FEE_RECIPIENT=0xa48c718AE6dE6599c5A46Fd6caBff54Def39473a \
BEGINNING_OF_TIME=1672531200 \
forge script script/VerificationV2.s.sol:Deploy --rpc-url https://ethereum-holesky.publicnode.com/ --broadcast --verify -vvvv
```

