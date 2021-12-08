const ProxyContract = artifacts.require('Proxy');
const Marketplace = artifacts.require('ECIOMarketplace');
const NFTcore = artifacts.require('ECIOTEST');

contract('', ([owner, user, someuser]) => {
  it('Proxy should call getListingPrice from Marketplace', async () => {
    // deploy nftCore
    let marketPlace = await Marketplace.new({ from: someuser });

    // get selector of initialize() function
    let data = marketPlace.contract.methods.initialize('425', '100').encodeABI();

    // deploy ProxyContract
    let proxyContract = await ProxyContract.new(marketPlace.address, data, { from: owner });

    // create SampleLogic1 instance at SampleProxy's address
    let marketInstance = await Marketplace.at(proxyContract.address);

    // check owner
    assert.equal(await marketInstance.owner(), owner);

    // check listingPrice
    assert.equal(await marketInstance.getListingPrice(), '100');
    assert.equal(await marketInstance.getfeesRate(), '425');

    // // deploy SampleLogic2
    // let sampleLogic2 = await SampleLogic2.new({ from: someuser });
    //
    // data = sampleLogic2.contract.methods.mint(user, '1000').encodeABI();
    //
    // // upgrade _implementation of Proxy to SampleLogic2's and mint to user 2000
    // await sampleProxy.upgradeToAndCall(sampleLogic2.address, data);
    //
    // // check user's balance
    // assert.equal(await realSampleLogic.balances(user), '3000');

  });
});
