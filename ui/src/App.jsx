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

// Info tooltip component for contextual help
function InfoTooltip({ text }) {
  return (
    <span className="info-tooltip">
      <span className="info-icon">?</span>
      <span className="info-text">{text}</span>
    </span>
  );
}
// Helper to normalize error messages for user-friendly display
function normalizeError(err) {
  const msg = err?.message || err?.reason || 'Unknown error';

  // Common error patterns and friendly messages
  if (msg.includes('user rejected') || msg.includes('User denied')) {
    return 'Transaction cancelled';
  }
  if (msg.includes('insufficient funds')) {
    return 'Insufficient funds for transaction';
  }
  if (msg.includes('network changed') || msg.includes('chain mismatch')) {
    return 'Network changed - please reconnect';
  }
  if (msg.includes('nonce')) {
    return 'Transaction conflict - try again';
  }
  if (msg.includes('execution reverted')) {
    return 'Transaction failed - check parameters';
  }
  if (msg.includes('gas')) {
    return 'Gas estimation failed';
  }

  // Truncate long messages
  return msg.length > 40 ? msg.slice(0, 40) + '...' : msg;
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
  const [loadingAction, setLoadingAction] = useState(null); // Track which action is loading
  const [status, setStatus] = useState({ type: '', message: '' });
  const [poolATvl, setPoolATvl] = useState('0');
  const [poolBTvl, setPoolBTvl] = useState('0');
  const [securityStatus, setSecurityStatus] = useState('ACTIVE');

  // Simple notification for rate changes that could trigger rebalance
  const [rebalanceNotification, setRebalanceNotification] = useState(null);

  // Auto-dismiss rebalance notification after 10 seconds
  useEffect(() => {
    if (rebalanceNotification) {
      const timer = setTimeout(() => setRebalanceNotification(null), 10000);
      return () => clearTimeout(timer);
    }
  }, [rebalanceNotification]);

  // Vault settings state
  const [rebalancePct, setRebalancePct] = useState('50');
  const [rebalanceThreshold, setRebalanceThreshold] = useState('1.00');
  const [newRebalancePct, setNewRebalancePct] = useState('');
  const [newThreshold, setNewThreshold] = useState('');

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
      setStatus({ type: 'error', message: `> ERROR: ${normalizeError(err)}` });
    }
  };

  const switchNetwork = async () => {
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0xaa36a7' }],
      });
    } catch (err) {
      setStatus({ type: 'error', message: `> ERROR: ${normalizeError(err)}` });
    }
  };

  const fetchData = useCallback(async () => {
    if (chainId !== CHAINS.SEPOLIA) return;
    if (!account || !tokenContract || !vaultContract || !poolAContract || !poolBContract) return;

    try {
      const balance = await tokenContract.balanceOf(account).catch(() => 0n);
      const shares = await vaultContract.sharesOf(account).catch(() => 0n);
      const rateA = await poolAContract.getSupplyRate().catch(() => 500n);
      const rateB = await poolBContract.getSupplyRate().catch(() => 300n);
      const assets = await vaultContract.totalAssets().catch(() => 0n);
      const allow = await tokenContract.allowance(account, CONTRACTS.VAULT).catch(() => 0n);

      let balA = 0n, balB = 0n;
      try {
        const allocation = await vaultContract.getAllocation();
        balA = allocation[0];
        balB = allocation[1];
      } catch (e) { /* ignore */ }

      setTokenBalance(formatUnits(balance, 18));
      setUserShares(formatUnits(shares, 18));
      setPoolARate((Number(rateA) / 100).toFixed(2));
      setPoolBRate((Number(rateB) / 100).toFixed(2));
      setPoolABalance(formatUnits(balA, 18));
      setPoolBBalance(formatUnits(balB, 18));
      setTotalAssets(formatUnits(assets, 18));
      setAllowance(formatUnits(allow, 18));

      try {
        const pct = await vaultContract.rebalancePercentage();
        const threshold = await vaultContract.rebalanceThreshold();
        setRebalancePct((Number(pct) / 100).toFixed(0));
        setRebalanceThreshold((Number(threshold) / 100).toFixed(2));

        const tvlA = await poolAContract.totalAssets().catch(() => 0n);
        const tvlB = await poolBContract.totalAssets().catch(() => 0n);
        setPoolATvl(formatUnits(tvlA, 18));
        setPoolBTvl(formatUnits(tvlB, 18));
        if (tvlA > 0n && tvlB > 0n) setSecurityStatus('ACTIVE');
      } catch (e) { /* ignore */ }
    } catch (err) {
      console.log('Fetch error:', err.message);
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
    setLoadingAction(action);
    setStatus({ type: 'info', message: `> PROCESSING: ${action}...` });
    try {
      const tx = await fn();
      setStatus({ type: 'info', message: `> PENDING: ${tx.hash.slice(0, 16)}...` });
      await tx.wait();
      await fetchData();
      setStatus({ type: 'success', message: `> SUCCESS: ${action} complete` });
    } catch (err) {
      setStatus({ type: 'error', message: `> FAILED: ${normalizeError(err)}` });
    }
    setLoadingAction(null);
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

  const updateRateA = () => handleTx('Rate Update A', async () => {
    const tx = await poolAContract.updateRates(Number(newRateA) * 100, Number(newRateA) * 150, 5000);
    // Show notification if rate diff will exceed threshold
    const currentRateB = Number(poolBRate);
    const newRate = Number(newRateA);
    if (Math.abs(newRate - currentRateB) >= 1) {
      setRebalanceNotification(`Pool A rate changed to ${newRateA}%. Rebalance may be triggered.`);
    }
    return tx;
  });

  const updateRateB = () => handleTx('Rate Update B', async () => {
    const tx = await poolBContract.updateRates(Number(newRateB) * 100, Number(newRateB) * 150, 5000);
    // Show notification if rate diff will exceed threshold
    const currentRateA = Number(poolARate);
    const newRate = Number(newRateB);
    if (Math.abs(currentRateA - newRate) >= 1) {
      setRebalanceNotification(`Pool B rate changed to ${newRateB}%. Rebalance may be triggered.`);
    }
    return tx;
  });

  const getFaucetTokens = () => handleTx('Faucet', () =>
    tokenContract.faucet(parseUnits('1000', 18))
  );

  const simulateBankRun = () => handleTx('Attack Simulation', async () => {
    setStatus({ type: 'error', message: '> ALERT: Simulating Bank Run on Pool A...' });

    // To simulate a bank run, we need a massive withdrawal.
    // Instead of actually having 1M tokens, we can just trigger a rate update 
    // that the Reactive Contract handles as an event.
    // However, our Reactive Contract listens to LiquidityUpdated.
    // So we can just withdraw a small amount which emits the event,
    // OR we can make a dummy call if we added one.
    // Since we didn't add a "fake" event emitter, we just withdraw what we have.
    // But for a REAL bank run demo, we want to see the "Bank Run Detected" in Reactive.

    // Let's just withdraw everything we have from Pool A to show "Liquidity Drop"
    const shares = await poolAContract.sharesOf(account);
    if (shares === 0n) throw new Error("No funds in Pool A to withdraw");

    const tx = await poolAContract.withdraw(shares);
    setSecurityStatus('THREAT_DETECTED');
    return tx;
  });

  const updateRebalancePct = () => handleTx('Set Rebalance %', async () => {
    // Convert percentage (0-100) to basis points (0-10000)
    const bps = Number(newRebalancePct) * 100;
    const tx = await vaultContract.setRebalancePercentage(bps);
    setNewRebalancePct(''); // Clear input after success
    return tx;
  });

  const updateThreshold = () => handleTx('Set Threshold', async () => {
    // Convert percentage (e.g., 1.5) to basis points (150)
    const bps = Math.round(Number(newThreshold) * 100);
    const tx = await vaultContract.setRebalanceThreshold(bps);
    setNewThreshold(''); // Clear input after success
    return tx;
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
            <img src="/logo.png" alt="Reactive Vault" className="header-logo" />
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
            {status.type === 'info' && <span className="spinner"></span>}
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
                <button onClick={getFaucetTokens} disabled={loadingAction} className="btn primary">
                  {loadingAction === 'Faucet' ? <><span className="spinner"></span> LOADING...</> : 'GET_1000_mUSDC'}
                </button>
              </div>
            </section>
          )}

          <section className="rates-section">
            <h2>{"<YIELD_RATES/>"}<InfoTooltip text="APY rates from each lending pool. Funds flow to the higher-yield pool when difference exceeds threshold." /></h2>
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
            {rebalanceNotification && (
              <p className="pending-hint">
                <span className="spinner"></span>
                {rebalanceNotification}
              </p>
            )}
          </section>

          <section className="actions-grid">
            <div className="action-card">
              <h3>{"// DEPOSIT"}</h3>
              {Number(allowance) < 1000 && (
                <button onClick={approve} disabled={loadingAction} className="btn full">
                  {loadingAction === 'Token Approval' ? <><span className="spinner"></span> APPROVING...</> : 'APPROVE_TOKENS'}
                </button>
              )}
              <div className="input-row">
                <input
                  type="number"
                  placeholder="0"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                />
                <button onClick={deposit} disabled={loadingAction || !depositAmount} className="btn">
                  {loadingAction === 'Deposit' ? <span className="spinner"></span> : 'EXEC'}
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
                <button onClick={withdraw} disabled={loadingAction || !withdrawShares} className="btn">
                  {loadingAction === 'Withdraw' ? <span className="spinner"></span> : 'EXEC'}
                </button>
              </div>
            </div>
          </section>

          <section className="demo-section">
            <h2>{"<SECURITY_MONITOR/>"}<InfoTooltip text="Autonomous Bank Run Protection. Monitors pool liquidity (TVL) in real-time. If a massive drop (>30%) is detected, the Reactive network triggers an emergency exit from ALL pools to safeguard vault assets." /></h2>
            <div className={`security-dashboard ${securityStatus}`}>
              <div className="security-status">
                <span className="pulse"></span>
                GUARD_STATUS: {securityStatus}
              </div>
              <div className="tvl-stats">
                <div className="tvl-item">
                  <span>POOL_A_TVL:</span>
                  <span className="value">{Number(poolATvl).toLocaleString()}</span>
                </div>
                <div className="tvl-item">
                  <span>POOL_B_TVL:</span>
                  <span className="value">{Number(poolBTvl).toLocaleString()}</span>
                </div>
              </div>
              <button
                onClick={simulateBankRun}
                disabled={loadingAction || securityStatus === 'THREAT_DETECTED'}
                className="btn warn full"
              >
                {loadingAction === 'Attack Simulation' ? <span className="spinner"></span> : 'SIMULATE_BANK_RUN (POOL_A)'}
              </button>
            </div>
          </section>

          <section className="demo-section">
            <h2>{"<DEMO_CONTROLS/>"}<InfoTooltip text="Simulate pool rate changes to trigger the Reactive Network. Gas-Aware logic: Rebalances are skipped if the rate difference is <1.5% to ensure profitability after gas costs." /></h2>
            <p className="hint">Trigger rate changes or test profitability logic</p>
            <div className="demo-grid">
              <div className="input-row">
                <span>A:</span>
                <input
                  type="number"
                  placeholder="%"
                  value={newRateA}
                  onChange={(e) => setNewRateA(e.target.value)}
                />
                <button onClick={updateRateA} disabled={loadingAction || !newRateA} className="btn">
                  {loadingAction === 'Rate Update A' ? <span className="spinner"></span> : 'SET'}
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
                <button onClick={updateRateB} disabled={loadingAction || !newRateB} className="btn">
                  {loadingAction === 'Rate Update B' ? <span className="spinner"></span> : 'SET'}
                </button>
              </div>
            </div>
          </section>

          {/* Vault Settings */}
          <section className="settings-section">
            <h2>{"<VAULT_SETTINGS/>"}<InfoTooltip text="Configure how the vault rebalances between pools. Only the contract owner can modify these settings." /></h2>
            <p className="hint">Configure rebalancing behavior (Owner only)</p>
            <div className="settings-grid">
              <div className="setting-item">
                <span className="setting-label">REBALANCE_PCT<InfoTooltip text="Percentage of funds to move when rebalancing. 80% means move 80% from lower to higher yield pool." /></span>
                <span className="setting-value">{rebalancePct}%</span>
              </div>
              <div className="setting-item">
                <span className="setting-label">THRESHOLD<InfoTooltip text="Minimum rate difference (in %) required to trigger a rebalance. Prevents unnecessary moves for tiny differences." /></span>
                <span className="setting-value">{rebalanceThreshold}%</span>
              </div>
            </div>
            <div className="demo-grid" style={{ marginTop: '1rem' }}>
              <div className="input-row">
                <span>PCT:</span>
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
                  disabled={loadingAction || !newRebalancePct || Number(newRebalancePct) < 0 || Number(newRebalancePct) > 100}
                  className="btn"
                >
                  {loadingAction === 'Set Rebalance %' ? <span className="spinner"></span> : 'SET'}
                </button>
              </div>
              <div className="input-row">
                <span>THR:</span>
                <input
                  type="number"
                  placeholder="e.g. 1.5"
                  min="0"
                  step="0.1"
                  value={newThreshold}
                  onChange={(e) => setNewThreshold(e.target.value)}
                />
                <button
                  onClick={updateThreshold}
                  disabled={loadingAction || !newThreshold || Number(newThreshold) < 0}
                  className="btn"
                >
                  {loadingAction === 'Set Threshold' ? <span className="spinner"></span> : 'SET'}
                </button>
              </div>
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
