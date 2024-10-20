# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes

test   :; forge test -vvv

# Deploy
deploy-ledger :; forge script ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv,--broadcast --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv --slow)
deploy-pk :; forge script ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv,--broadcast --private-key ${PRIVATE_KEY} --verify -vvvv --slow)

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# Deploy Seamless
deploy-SeamlessStaticATokenFactory :; forge script scripts/seamless/DeploySeamlessStaticATokenFactory.s.sol --tc DeploySeamlessStaticATokenFactory --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-StataOracle :; forge script scripts/seamless/DeployStataOracle.s.sol --tc DeployStataOracle --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv