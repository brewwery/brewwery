import type { HTMLAttributes } from "react";

export function Tooltip({ title, children }: HTMLAttributes<HTMLSpanElement>) {
  return <span title={title}>{children}</span>;
}
