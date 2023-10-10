import "./App.css";
import Header from "./components/Header";
import { Routes, Route } from "react-router-dom";
import Swap from "./components/Swap";
function App() {

  return (
    <>
      <div className="App">
        <Header />

        <div className="mainWindow">
          <Routes>
            <Route
              path="/"
              element={
                <Swap />
              }
            />
          </Routes>
        </div>
      </div>
    </>
  );
}

export default App;
