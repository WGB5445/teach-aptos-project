import './App.css'
import Header from './components/Header'
import { Routes, Route } from 'react-router-dom'
import Swap from './components/Swap'
import { Faucet } from './components/Faucet'
function App() {
  return (
    <>
      <div className="App">
        <Header />

        <div className="mainWindow">
          <Routes>
            <Route path="/" element={<Swap />} />
            <Route path="/faucet" element={<Faucet />} />
          </Routes>
        </div>
      </div>
    </>
  )
}

export default App
