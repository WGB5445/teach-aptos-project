import Apt from '../assets/apt.svg'
import { Link } from 'react-router-dom'
import { WalletSelector } from '@aptos-labs/wallet-adapter-ant-design'

export default function Header() {
  return (
    <header>
      <div className="leftH">
        {/* <img src={Logo} alt="logo" className="logo" /> */}
        <Link to="/" className="link">
          <div className="headerItem">Swap</div>
        </Link>
        <Link to="/faucet" className="link">
          <div className="headerItem">Faucet</div>
        </Link>
      </div>
      <div className="rightH">
        <div className="headerItem">
          <img src={Apt} alt="apt" className="apt" />
          Aptos
        </div>
        <div className="connectButton">
          <WalletSelector />
        </div>
      </div>
    </header>
  )
}
