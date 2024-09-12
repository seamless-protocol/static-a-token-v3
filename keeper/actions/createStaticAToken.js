const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');

const staticATokenFactoryABI = ["function createStaticATokens(address[] memory underlyings) external returns (address[] memory)"];
const staticATokenFactoryAddress = '0x6bb79764b405955a22c2e850c40d9daf82a3f407';

// create staticAToken with the given underlying address
async function createStaticAToken(underlyingAddress, signer) {
  const staticATokenFactory = new ethers.Contract(staticATokenFactoryAddress, staticATokenFactoryABI, signer);

  const newStaticATokenAddress = 
    await staticATokenFactory.callStatic.createStaticATokens([underlyingAddress]);

  const tx = await staticATokenFactory.createStaticATokens([underlyingAddress]);
  await tx.wait();
  console.log(`New staticAToken created for the underlying:${underlyingAddress} staticAToken:${newStaticATokenAddress[0]}`);
  return { tx: tx.hash }
}

// Entrypoint for the action
// This action is called on every IPoolConfigurator.ReserveInitialized event
exports.handler = async function (payload) {
  const provider = new DefenderRelayProvider(payload);
  const signer = new DefenderRelaySigner(payload, provider, { speed: 'fast' });

  console.log("=== body ===");
  console.log(payload.request.body);
  console.log("=== matchReasons ===");
  console.log(payload.request.body.matchReasons);

  // from the IPoolConfigurator.ReserveInitialized event
  for(const matchReason of payload.request.body.matchReasons) {
    await createStaticAToken(matchReason.params.asset, signer);
  }
}

// unit testing
exports.createStaticAToken = createStaticAToken;