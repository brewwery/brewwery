import { useVirtualizer } from "@tanstack/react-virtual";
import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export interface VirtualizedColumn<T> {
  header: string;
  className?: string;
  render: (item: T) => ReactNode;
}

interface VirtualizedDataTableProps<T> {
  ariaLabel: string;
  columns: Array<VirtualizedColumn<T>>;
  getKey: (item: T) => string;
  gridTemplateColumns: string;
  items: T[];
  onActivate: (item: T) => void;
  rowHeight?: number;
}

export function VirtualizedDataTable<T>({
  ariaLabel,
  columns,
  getKey,
  gridTemplateColumns,
  items,
  onActivate,
  rowHeight = 76
}: VirtualizedDataTableProps<T>) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => rowHeight,
    overscan: 8
  });

  useEffect(() => {
    setActiveIndex((index) => Math.max(0, Math.min(index, items.length - 1)));
  }, [items.length]);

  const moveTo = (index: number) => {
    const next = Math.max(0, Math.min(index, items.length - 1));
    setActiveIndex(next);
    virtualizer.scrollToIndex(next, { align: "auto" });
  };

  return (
    <div aria-label={ariaLabel} role="grid" aria-rowcount={items.length + 1}>
      <div className="grid border-b border-border bg-[var(--brewwery-card)]" role="row" style={{ gridTemplateColumns }}>
        {columns.map((column) => (
          <div key={column.header} className={cn("px-4 py-3 text-left text-xs font-medium text-muted-foreground", column.className)} role="columnheader">
            {column.header}
          </div>
        ))}
      </div>
      <div
        ref={scrollRef}
        className="max-h-[min(560px,calc(100vh-330px))] min-h-24 overflow-auto outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[color:var(--brewwery-focus-ring)]"
        tabIndex={0}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown") {
            event.preventDefault();
            moveTo(activeIndex + 1);
          } else if (event.key === "ArrowUp") {
            event.preventDefault();
            moveTo(activeIndex - 1);
          } else if (event.key === "Home") {
            event.preventDefault();
            moveTo(0);
          } else if (event.key === "End") {
            event.preventDefault();
            moveTo(items.length - 1);
          } else if ((event.key === "Enter" || event.key === " ") && items[activeIndex]) {
            event.preventDefault();
            const item = items[activeIndex];
            if (item) onActivate(item);
          }
        }}
      >
        <div className="relative w-full" style={{ height: virtualizer.getTotalSize() }}>
          {virtualizer.getVirtualItems().map((virtualRow) => {
            const item = items[virtualRow.index];
            if (!item) return null;
            const active = virtualRow.index === activeIndex;
            return (
              <div
                key={getKey(item)}
                aria-rowindex={virtualRow.index + 2}
                aria-selected={active}
                className={cn(
                  "absolute left-0 top-0 grid w-full cursor-pointer items-center border-b border-border hover:bg-[var(--brewwery-card-hover)]",
                  active && "bg-[var(--brewwery-card-hover)]"
                )}
                role="row"
                style={{ height: virtualRow.size, transform: `translateY(${virtualRow.start}px)`, gridTemplateColumns }}
                onClick={() => {
                  setActiveIndex(virtualRow.index);
                  onActivate(item);
                }}
              >
                {columns.map((column) => (
                  <div key={column.header} className={cn("min-w-0 px-4 py-3 text-sm", column.className)} role="gridcell">
                    {column.render(item)}
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
