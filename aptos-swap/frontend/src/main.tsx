import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import { BrowserRouter } from 'react-router-dom'
import { PetraWallet } from 'petra-plugin-wallet-adapter'
import { AptosWalletAdapterProvider } from '@aptos-labs/wallet-adapter-react'
import '@aptos-labs/wallet-adapter-ant-design/dist/index.css'

const wallets = [new PetraWallet()]
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AptosWalletAdapterProvider plugins={wallets} autoConnect={true}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AptosWalletAdapterProvider>
  </React.StrictMode>,
)
