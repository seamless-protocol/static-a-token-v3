const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

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

  try {
    const tx = await staticAToken.refreshRewardTokens();
    await tx.wait();
    console.log(`Refreshed rewards on underlying:${underlying} staticAToken:${staticATokenAddress}`);
    return { tx: tx.hash }
  } catch (err) {
    console.error('An error occurred on refreshRewards call: ', err);
  }
}

// Entrypoint for the action
// This action is called on every IRewardsDistributor.AssetConfigUpdated event
exports.handler = async function (payload) {
  const client = new Defender(payload);

  const provider = client.relaySigner.getProvider();
  const signer = client.relaySigner.getSigner(provider, {
      speed: 'fast',
  });

  // from the IRewardsDistributor.AssetConfigUpdated event
  const aTokenAddress = payload.request.body.matchReasons.params.asset;

  await refreshRewards(aTokenAddress, signer);
}

// unit testing
exports.refreshRewards = refreshRewards;