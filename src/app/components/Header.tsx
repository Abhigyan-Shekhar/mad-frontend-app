import { Link } from "react-router";
import { MapPin } from "lucide-react";

interface HeaderProps {
  currentPage?: string;
}

export function Header({ currentPage }: HeaderProps) {
  return (
    <header className="bg-white border-b border-gray-200">
      <div className="max-w-[1400px] mx-auto px-8 py-4 flex items-center justify-between">
        <Link to="/" className="flex items-center gap-3">
          <div className="bg-black rounded-full p-2">
            <MapPin className="w-4 h-4 text-white" />
          </div>
          <div>
            <div className="text-[10px] text-gray-500 uppercase tracking-widest">SafeRoute</div>
            <div className="text-sm -mt-0.5">{currentPage || "Navigate with confidence"}</div>
          </div>
        </Link>

        <nav className="flex items-center gap-8">
          <Link to="/" className="text-sm hover:text-gray-600 transition-colors">
            Home
          </Link>
          <Link to="/plan-journey" className="text-sm hover:text-gray-600 transition-colors">
            Routes
          </Link>
          <Link to="/safety-score" className="text-sm hover:text-gray-600 transition-colors">
            Safety Score
          </Link>
          <Link to="/guardian-mode" className="text-sm hover:text-gray-600 transition-colors">
            Guardian Mode
          </Link>
          <button className="px-5 py-2 bg-black text-white rounded-md text-sm hover:bg-gray-800 transition-colors ml-2">
            Sign In
          </button>
        </nav>
      </div>
    </header>
  );
}
