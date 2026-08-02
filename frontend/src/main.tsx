import React from "react";
import ReactDOM from "react-dom";
import App from "./App";

// React 16 mounts with ReactDOM.render(...). Milestone U upgrades this to React
// 18's createRoot: ReactDOM.createRoot(el).render(<App/>). Keeping it on 16 now is
// deliberate — it's the starting point for the 16 -> 18 upgrade demo.
ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById("root"),
);
