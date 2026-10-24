"use strict";

import * as React from "react";
import { cn } from "./utils";

export interface DialogProps extends React.HTMLAttributes<HTMLDivElement> {
  open: boolean;
  onClose: () => void;
  title?: string;
}

const Dialog = React.forwardRef<HTMLDivElement, DialogProps>(
  ({ open, onClose, title, children, className, ...props }, ref) => {
    return (
      <>
        {open && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={onClose}>
            <div className="bg-background rounded-xl p-6 shadow-lg w-full max-w-md border border-border" role="dialog" aria-modal="true" {...props} ref={ref}>
              {title && <h2 className="text-lg font-bold mb-4">{title}</h2>}
              {children}
              <button onClick={onClose} className="mt-4 text-sm text-gray-500 hover:text-gray-900">إغلاق</button>
            </div>
          </div>
        )}
      </>
    );
  }
);
Dialog.displayName = "Dialog";

export { Dialog };
