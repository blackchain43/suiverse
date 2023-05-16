import React, { useState, useEffect, useCallback } from "react";
import { JsonRpcProvider, testnetConnection } from "@mysten/sui.js";
import { useWallet, ConnectModal, ConnectButton } from "@suiet/wallet-kit";
const provider = new JsonRpcProvider(testnetConnection);
function App() {
  const [showModal, setShowModal] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const wallet = useWallet();
  const handleTestWithSui = useCallback(() => {
    if (!wallet.connected) {
      return;
    }
  }, [wallet]);
  return (
    <div className="flex items-center gap-5">
      <div>
        {!wallet.connected ? (
          <ConnectButton>Connect Wallet</ConnectButton>
        ) : (
          <button
            className="flex items-center justify-center p-4 text-base font-semibold rounded-xl min-h-[56px] bg-blue-400 my-5"
            onClick={() => {
              wallet.disconnect();
            }}
          >
            Disconnect
          </button>
        )}
      </div>
      <div>
        <button
          className="flex items-center justify-center p-4 text-base font-semibold rounded-xl min-h-[56px] bg-blue-400"
          onClick={handleTestWithSui}
        >
          {" "}
          Test{" "}
        </button>
      </div>
    </div>
  );
}

export default App;
