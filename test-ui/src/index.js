import React from "react";
import ReactDOM from "react-dom/client";
import "./index.scss";
import App from "./App";
import { WalletProvider, SuietWallet } from "@suiet/wallet-kit";
import "@suiet/wallet-kit/style.css";

window.Buffer = window.Buffer || require("buffer").Buffer;

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <React.StrictMode>
    <WalletProvider defaultWallets={[SuietWallet]}>
      <App />
    </WalletProvider>
  </React.StrictMode>
);
