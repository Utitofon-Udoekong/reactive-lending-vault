import { useState, useEffect, useCallback } from 'react';
import { BrowserProvider, Contract, formatUnits, parseUnits } from 'ethers';
import { CONTRACTS, TOKEN_ABI, POOL_ABI, VAULT_ABI, CHAINS } from './contracts';
import './App.css';

// Binary Rain Background Component
function BinaryRain() {
  useEffect(() => {
    const canvas = document.getElementById('matrix');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const chars = '01';
    const fontSize = 14;
    const columns = canvas.width / fontSize;
    const drops = Array(Math.floor(columns)).fill(1);

    const draw = () => {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.fillStyle = '#0fa';
      ctx.font = `${fontSize}px monospace`;

      drops.forEach((y, i) => {
        const text = chars[Math.floor(Math.random() * chars.length)];
        const x = i * fontSize;
        ctx.fillStyle = `rgba(0, 255, 170, ${Math.random() * 0.5 + 0.1})`;
        ctx.fillText(text, x, y * fontSize);

        if (y * fontSize > canvas.height && Math.random() > 0.975) {
          drops[i] = 0;
        }
        drops[i]++;
      });
    };

    const interval = setInterval(draw, 50);

    const handleResize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    window.addEventListener('resize', handleResize);

    return () => {
      clearInterval(interval);
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return <canvas id="matrix" />;
}

function App() {
  const [account, setAccount] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [tokenContract, setTokenContract] = useState(null);
  const [poolAContract, setPoolAContract] = useState(null);
  const [poolBContract, setPoolBContract] = useState(null);
  const [vaultContract, setVaultContract] = useState(null);

  const [tokenBalance, setTokenBalance] = useState('0');
  const [userShares, setUserShares] = useState('0');
  const [poolARate, setPoolARate] = useState('5.00');
  const [poolBRate, setPoolBRate] = useState('3.00');
  const [poolABalance, setPoolABalance] = useState('700000');
  const [poolBBalance, setPoolBBalance] = useState('300000');
  const [totalAssets, setTotalAssets] = useState('1000000');
  const [allowance, setAllowance] = useState('0');

  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawShares, setWithdrawShares] = useState('');
  const [newRateA, setNewRateA] = useState('');
  const [newRateB, setNewRateB] = useState('');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState({ type: '', message: '' });

  // Vault settings state
  const [rebalancePct, setRebalancePct] = useState('50');
  const [rebalanceThreshold, setRebalanceThreshold] = useState('100');
  const [newRebalancePct, setNewRebalancePct] = useState('');

  const connectWallet = async () => {
    try {
      if (!window.ethereum) {
        setStatus({ type: 'error', message: '> ERROR: MetaMask not detected' });
        return;
      }
      const provider = new BrowserProvider(window.ethereum);
      const accounts = await provider.send('eth_requestAccounts', []);
      const signer = await provider.getSigner();
      const network = await provider.getNetwork();

      setAccount(accounts[0]);
      setChainId(Number(network.chainId));
      setTokenContract(new Contract(CONTRACTS.TOKEN, TOKEN_ABI, signer));
      setPoolAContract(new Contract(CONTRACTS.POOL_A, POOL_ABI, signer));
      setPoolBContract(new Contract(CONTRACTS.POOL_B, POOL_ABI, signer));
      setVaultContract(new Contract(CONTRACTS.VAULT, VAULT_ABI, signer));
      setStatus({ type: 'success', message: '> CONNECTED: Wallet linked successfully' });
    } catch (err) {
      setStatus({ type: 'error', message: `> ERROR: ${err.message}` });
    }
  };

  const switchNetwork = async () => {
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0xaa36a7' }],
      });
    } catch (err) {
      setStatus({ type: 'error', message: `> ERROR: ${err.message}` });
    }
  };

  const fetchData = useCallback(async () => {
    // Don't fetch if not on Sepolia
    if (chainId !== CHAINS.SEPOLIA) return;
    if (!account || !tokenContract || !vaultContract || !poolAContract || !poolBContract) return;

    try {
      // Fetch each separately to handle partial failures
      const balance = await tokenContract.balanceOf(account).catch(() => 0n);
      const shares = await vaultContract.sharesOf(account).catch(() => 0n);
      const rateA = await poolAContract.getSupplyRate().catch(() => 500n);
      const rateB = await poolBContract.getSupplyRate().catch(() => 300n);
      const assets = await vaultContract.totalAssets().catch(() => 0n);
      const allow = await tokenContract.allowance(account, CONTRACTS.VAULT).catch(() => 0n);

      // Get pool allocations (returns [poolAAlloc, poolBAlloc])
      let balA = 0n, balB = 0n;
      try {
        const allocation = await vaultContract.getAllocation();
        balA = allocation[0];
        balB = allocation[1];
      } catch {
        // Fallback if getAllocation fails
      }

      setTokenBalance(formatUnits(balance, 18));
      setUserShares(formatUnits(shares, 18));
      setPoolARate((Number(rateA) / 100).toFixed(2));
      setPoolBRate((Number(rateB) / 100).toFixed(2));
      setPoolABalance(formatUnits(balA, 18));
      setPoolBBalance(formatUnits(balB, 18));
      setTotalAssets(formatUnits(assets, 18));
      setAllowance(formatUnits(allow, 18));

      // Fetch vault settings
      try {
        const pct = await vaultContract.rebalancePercentage();
        const threshold = await vaultContract.rebalanceThreshold();
        setRebalancePct((Number(pct) / 100).toFixed(0));
        setRebalanceThreshold((Number(threshold) / 100).toFixed(2));
      } catch {
        // Use defaults if fetch fails
      }
    } catch (err) {
      // Silently ignore fetch errors (usually network issues)
      console.log('Fetch skipped:', err.message?.slice(0, 50));
    }
  }, [account, chainId, tokenContract, vaultContract, poolAContract, poolBContract]);

  useEffect(() => {
    if (account && chainId === CHAINS.SEPOLIA) {
      fetchData();
      const interval = setInterval(fetchData, 5000);
      return () => clearInterval(interval);
    }
  }, [account, chainId, fetchData]);

  const handleTx = async (action, fn) => {
    setLoading(true);
    setStatus({ type: 'info', message: `> PROCESSING: ${action}...` });
    try {
      const tx = await fn();
      setStatus({ type: 'info', message: `> PENDING: ${tx.hash.slice(0, 16)}...` });
      await tx.wait();
      await fetchData();
      setStatus({ type: 'success', message: `> SUCCESS: ${action} complete` });
    } catch (err) {
      setStatus({ type: 'error', message: `> FAILED: ${err.message?.slice(0, 50)}` });
    }
    setLoading(false);
  };

  const approve = () => handleTx('Token Approval', () =>
    tokenContract.approve(CONTRACTS.VAULT, parseUnits('1000000', 18))
  );

  const deposit = () => handleTx('Deposit', () =>
    vaultContract.deposit(parseUnits(depositAmount, 18))
  );

  const withdraw = () => handleTx('Withdraw', () =>
    vaultContract.withdraw(parseUnits(withdrawShares, 18))
  );

  const updateRateA = () => handleTx('Rate Update A', () =>
    poolAContract.updateRates(Number(newRateA) * 100, Number(newRateA) * 150, 5000)
  );

  const updateRateB = () => handleTx('Rate Update B', () =>
    poolBContract.updateRates(Number(newRateB) * 100, Number(newRateB) * 150, 5000)
  );

  const getFaucetTokens = () => handleTx('Faucet', () =>
    tokenContract.faucet(parseUnits('1000', 18))
  );

  const updateRebalancePct = () => handleTx('Set Rebalance %', async () => {
    // Convert percentage (0-100) to basis points (0-10000)
    const bps = Number(newRebalancePct) * 100;
    return vaultContract.setRebalancePercentage(bps);
  });

  const rateDiff = Math.abs(Number(poolARate) - Number(poolBRate)).toFixed(2);
  const higherPool = Number(poolARate) > Number(poolBRate) ? 'A' : 'B';
  const total = Number(poolABalance) + Number(poolBBalance);
  const pctA = total > 0 ? ((Number(poolABalance) / total) * 100).toFixed(0) : 50;
  const pctB = total > 0 ? ((Number(poolBBalance) / total) * 100).toFixed(0) : 50;

  return (
    <>
      <BinaryRain />
      <div className="app">
        <header>
          <div className="logo">
            <span className="bracket">[</span>
            <span className="title">REACTIVE VAULT</span>
            <span className="bracket">]</span>
          </div>
          <p className="tagline">// Automated Yield Optimization</p>

          {!account ? (
            <button onClick={connectWallet} className="btn primary">
              CONNECT_WALLET
            </button>
          ) : (
            <div className="wallet">
              <span className="address">{account.slice(0, 6)}...{account.slice(-4)}</span>
              {chainId !== CHAINS.SEPOLIA && (
                <button onClick={switchNetwork} className="btn warn">SWITCH_NETWORK</button>
              )}
              <button onClick={() => {
                setAccount(null);
                setTokenContract(null);
                setVaultContract(null);
                setPoolAContract(null);
                setPoolBContract(null);
                setStatus({ type: 'info', message: '> DISCONNECTED: Wallet unlinked' });
              }} className="btn">DISCONNECT</button>
            </div>
          )}
        </header>

        {status.message && (
          <div className={`terminal-output ${status.type}`}>
            {status.message}
          </div>
        )}

        {account && chainId !== CHAINS.SEPOLIA && (
          <div className="terminal-output error">
            {"> ERROR: Wrong network! Please switch to Sepolia (Chain ID: 11155111)"}
          </div>
        )}

        <main>
          <section className="stats-grid">
            <div className="stat-card">
              <span className="stat-label">TOTAL_LOCKED</span>
              <span className="stat-value">{Number(totalAssets).toLocaleString()}</span>
              <span className="stat-unit">mUSDC</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">YOUR_SHARES</span>
              <span className="stat-value accent">{Number(userShares).toLocaleString()}</span>
              <span className="stat-unit">shares</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">WALLET_BAL</span>
              <span className="stat-value">{Number(tokenBalance).toLocaleString()}</span>
              <span className="stat-unit">mUSDC</span>
            </div>
          </section>

          {/* Faucet Section - Get Test Tokens */}
          {account && Number(tokenBalance) < 100 && (
            <section className="faucet-section">
              <div className="faucet-content">
                <span>{">> NEED_TOKENS?"}</span>
                <button onClick={getFaucetTokens} disabled={loading} className="btn primary">
                  GET_1000_mUSDC
                </button>
              </div>
            </section>
          )}

          <section className="rates-section">
            <h2>{"<YIELD_RATES/>"}</h2>
            <div className="rates-display">
              <div className="rate-box">
                <span className="pool-id">POOL_A</span>
                <span className="rate-value">{poolARate}%</span>
              </div>
              <div className="rate-divider">
                <span className="diff">{rateDiff}%</span>
                <span className="diff-label">ΔDIFF</span>
              </div>
              <div className="rate-box alt">
                <span className="pool-id">POOL_B</span>
                <span className="rate-value">{poolBRate}%</span>
              </div>
            </div>
            <div className="allocation-bar">
              <div className="bar-a" style={{ width: `${pctA}%` }}>{pctA}%</div>
              <div className="bar-b" style={{ width: `${pctB}%` }}>{pctB}%</div>
            </div>
            <div className="pool-balances">
              <span>POOL_A: {Number(poolABalance).toLocaleString()} mUSDC</span>
              <span>POOL_B: {Number(poolBBalance).toLocaleString()} mUSDC</span>
            </div>
            <p className="status-text">
              {Number(rateDiff) >= 1
                ? `>> REBALANCE ACTIVE → Pool ${higherPool}`
                : '>> THRESHOLD NOT MET (1% required)'}
            </p>
          </section>

          <section className="actions-grid">
            <div className="action-card">
              <h3>{"// DEPOSIT"}</h3>
              {Number(allowance) < 1000 && (
                <button onClick={approve} disabled={loading} className="btn full">
                  APPROVE_TOKENS
                </button>
              )}
              <div className="input-row">
                <input
                  type="number"
                  placeholder="0"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                />
                <button onClick={deposit} disabled={loading || !depositAmount} className="btn">
                  EXEC
                </button>
              </div>
            </div>

            <div className="action-card">
              <h3>{"// WITHDRAW"}</h3>
              <div className="input-row">
                <input
                  type="number"
                  placeholder="0"
                  value={withdrawShares}
                  onChange={(e) => setWithdrawShares(e.target.value)}
                />
                <button onClick={withdraw} disabled={loading || !withdrawShares} className="btn">
                  EXEC
                </button>
              </div>
            </div>
          </section>

          <section className="demo-section">
            <h2>{"<DEMO_CONTROLS/>"}</h2>
            <p className="hint">Trigger rate changes to test reactive automation</p>
            <div className="demo-grid">
              <div className="input-row">
                <span>A:</span>
                <input
                  type="number"
                  placeholder="%"
                  value={newRateA}
                  onChange={(e) => setNewRateA(e.target.value)}
                />
                <button onClick={updateRateA} disabled={loading || !newRateA} className="btn">
                  SET
                </button>
              </div>
              <div className="input-row">
                <span>B:</span>
                <input
                  type="number"
                  placeholder="%"
                  value={newRateB}
                  onChange={(e) => setNewRateB(e.target.value)}
                />
                <button onClick={updateRateB} disabled={loading || !newRateB} className="btn">
                  SET
                </button>
              </div>
            </div>
          </section>

          {/* Vault Settings */}
          <section className="settings-section">
            <h2>{"<VAULT_SETTINGS/>"}</h2>
            <p className="hint">Configure rebalancing behavior (Owner only)</p>
            <div className="settings-grid">
              <div className="setting-item">
                <span className="setting-label">REBALANCE_PCT</span>
                <span className="setting-value">{rebalancePct}%</span>
              </div>
              <div className="setting-item">
                <span className="setting-label">THRESHOLD</span>
                <span className="setting-value">{rebalanceThreshold}%</span>
              </div>
            </div>
            <div className="input-row" style={{ marginTop: '1rem' }}>
              <span>NEW_PCT:</span>
              <input
                type="number"
                placeholder="0-100"
                min="0"
                max="100"
                value={newRebalancePct}
                onChange={(e) => setNewRebalancePct(e.target.value)}
              />
              <button
                onClick={updateRebalancePct}
                disabled={loading || !newRebalancePct || Number(newRebalancePct) < 0 || Number(newRebalancePct) > 100}
                className="btn"
              >
                SET
              </button>
            </div>
          </section>

          <section className="contracts-section">
            <h2>{"<CONTRACTS/>"}</h2>
            <div className="contract-grid">
              <a href={`https://sepolia.etherscan.io/address/${CONTRACTS.VAULT}`} target="_blank" rel="noreferrer">
                VAULT: {CONTRACTS.VAULT.slice(0, 10)}...
              </a>
              <a href={`https://lasna.reactscan.net/address/${CONTRACTS.REACTIVE}`} target="_blank" rel="noreferrer">
                REACTIVE: {CONTRACTS.REACTIVE.slice(0, 10)}...
              </a>
            </div>
          </section>
        </main>

        <footer>
          <span>POWERED BY</span>
          <a href="https://reactive.network" target="_blank" rel="noreferrer">REACTIVE.NETWORK</a>
        </footer>
      </div>
    </>
  );
}

export default App;
