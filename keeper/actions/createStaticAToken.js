const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const staticATokenFactoryABI = ["function createStaticATokens(address[] memory underlyings) external returns (address[] memory)"];
const staticATokenFactoryAddress = '0x6bb79764b405955a22c2e850c40d9daf82a3f407';

// create staticAToken with the given underlying address
async function createStaticAToken(underlyingAddress, signer) {
  const staticATokenFactory = new ethers.Contract(staticATokenFactoryAddress, staticATokenFactoryABI, signer);

  try {
    const newStatciATokenAddress = 
      await staticATokenFactory.callStatic.createStaticATokens([underlyingAddress]);

    let tx = await staticATokenFactory.createStaticATokens([underlyingAddress]);
    await tx.wait();
    console.log(`New staticAToken created for the underlying:${underlyingAddress} staticAToken:${newStatciATokenAddress}`);
    return { tx: tx.hash }
  } catch (err) {
    console.error('An error occurred on creating staticAtoken call: ', err);
  }
}

// Entrypoint for the action
exports.handler = async function (payload) {
  const client = new Defender(payload);

  const provider = client.relaySigner.getProvider();
  const signer = client.relaySigner.getSigner(provider, {
      speed: 'fast',
  });

  const underlyingAddress = payload.request.body.matchReasons.params.asset;

  await createStaticAToken(underlyingAddress, signer);
}

// unit testing
exports.createStaticAToken = createStaticAToken;