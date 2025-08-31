import * as React from "react";
type TabsContext = { value: string; onValueChange?: (v: string) => void };
const Ctx = React.createContext<TabsContext>({ value: "" });
export function Tabs({ value, onValueChange, children }: { value: string; onValueChange?: (v: string) => void; children: React.ReactNode }) {
  return <Ctx.Provider value={{ value, onValueChange }}>{children}</Ctx.Provider>;
}
export function TabsList({ children }: { children: React.ReactNode }) {
  return <div className="inline-flex gap-2 p-1 rounded-lg bg-zinc-100 border">{children}</div>;
}
export function TabsTrigger({ value, children }: { value: string; children: React.ReactNode }) {
  const ctx = React.useContext(Ctx);
  const active = ctx.value === value;
  return (
    <button className={"px-3 py-1 rounded-md text-sm " + (active ? "bg-white border" : "hover:bg-white/50")} onClick={() => ctx.onValueChange?.(value)}>
      {children}
    </button>
  );
}
