const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');

const staticATokenABI = ["function refreshRewardTokens() external"];

const staticATokenFactoryABI = ["function getStaticAToken(address underlying) external view returns (address)"];
const staticATokenFactoryAddress = '0x6bb79764b405955a22c2e850c40d9daf82a3f407';

const aTokenABI = ["function UNDERLYING_ASSET_ADDRESS() external view returns (address)"];

// refresh the rewards on the static token for the given aToken address
async function refreshRewards(aTokenAddress, signer) {
  const aToken = new ethers.Contract(aTokenAddress, aTokenABI, signer);

  const underlyingAddress = aToken.UNDERLYING_ASSET_ADDRESS();

  const staticATokenFactory = new ethers.Contract(staticATokenFactoryAddress, staticATokenFactoryABI, signer);

  const staticATokenAddress = staticATokenFactory.getStaticAToken(underlyingAddress);
  const staticAToken = new ethers.Contract(staticATokenAddress, staticATokenABI, signer);

  const tx = await staticAToken.refreshRewardTokens();
  await tx.wait();
  console.log(`Refreshed rewards on underlying:${underlyingAddress} staticAToken:${staticATokenAddress}`);
  return { tx: tx.hash }
}

// Entrypoint for the action
// This action is called on every IRewardsDistributor.AssetConfigUpdated event
exports.handler = async function (payload) {
  const provider = new DefenderRelayProvider(payload);
  const signer = new DefenderRelaySigner(payload, provider, { speed: 'fast' });

  console.log("=== body ===");
  console.log(payload.request.body);
  console.log("=== matchReasons ===");
  console.log(payload.request.body.matchReasons);

  // from the IRewardsDistributor.AssetConfigUpdated event
  const aTokenAddress = payload.request.body.matchReasons[0].params.asset;

  await refreshRewards(aTokenAddress, signer);
}

// unit testing
exports.refreshRewards = refreshRewards;