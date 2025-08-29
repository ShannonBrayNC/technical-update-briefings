import React from "react";
import { createRoot } from "react-dom/client";
import MeetingTab from "./MeetingTab";

const el = document.getElementById("root");
if (!el) {
  const msg = document.createElement("pre");
  msg.textContent = "Root div #root not found";
  document.body.appendChild(msg);
} else {
  createRoot(el).render(<MeetingTab />);
}
