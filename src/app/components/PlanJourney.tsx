import { Header } from "./Header";
import { MapPin, Shield } from "lucide-react";
import { Link } from "react-router";

export function PlanJourney() {
  return (
    <div className="min-h-screen bg-[#FAF9F6]">
      <Header currentPage="Plan your journey" />

      <main className="max-w-[1400px] mx-auto px-8 py-12">
        {/* Location Inputs */}
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-10">
          <div className="grid grid-cols-2 gap-6 mb-5">
            <div>
              <label className="text-sm text-gray-600 mb-2 block">From</label>
              <div className="flex items-center gap-3 border border-gray-300 rounded-lg px-4 py-3 bg-white">
                <MapPin className="w-5 h-5 text-gray-400" />
                <span className="text-base">Current Location</span>
              </div>
            </div>
            <div>
              <label className="text-sm text-gray-600 mb-2 block">To</label>
              <div className="flex items-center gap-3 border border-gray-300 rounded-lg px-4 py-3 bg-white">
                <MapPin className="w-5 h-5 text-gray-400" />
                <span className="text-base">The Good Centre, Aline Rd</span>
              </div>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-sm text-gray-600">
              <Shield className="w-4 h-4" />
              <span>SOS deadzone detection enabled</span>
            </div>
            <div className="flex gap-3">
              <button className="px-5 py-2 border border-gray-300 bg-white rounded-lg text-sm">
                Filters
              </button>
              <button className="px-5 py-2 bg-black text-white rounded-lg text-sm">
                Find routes
              </button>
            </div>
          </div>
        </div>

        {/* Route Options */}
        <div className="grid grid-cols-3 gap-6 mb-10">
          {/* Well-lit Streets */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs text-gray-500 uppercase tracking-wider">Recommended</div>
                <div className="text-xs bg-green-100 text-green-700 px-2.5 py-1 rounded-md font-medium">Safety #1</div>
              </div>
              <h3 className="text-xl mb-2 font-medium">Well-lit Streets</h3>
              <p className="text-sm text-gray-600 mb-6 leading-relaxed">
                Routes prioritize safe, well-lit traffic, even lighting, fewer incident density.
              </p>

              <div className="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">Duration</div>
                  <div className="text-2xl font-medium">18 min</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">SOS Coverage</div>
                  <div className="text-2xl font-medium">Full</div>
                </div>
              </div>

              <div className="mb-6">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Passing Status</div>
                <div className="text-sm text-gray-600 leading-relaxed">
                  No poor-service signal stretches. Better
                  emergency vehicle access throughout. High
                  lighting availability.
                </div>
              </div>

              <div className="bg-[#1a1a1a] rounded-lg p-6 h-36 flex items-center justify-center">
                <svg className="w-full h-full" viewBox="0 0 280 120">
                  <path
                    d="M 30,90 Q 70,70 110,60 Q 150,50 190,45 Q 220,40 250,35"
                    fill="none"
                    stroke="#10b981"
                    strokeWidth="3"
                    strokeLinecap="round"
                  />
                  <circle cx="30" cy="90" r="5" fill="#10b981" />
                  <circle cx="110" cy="60" r="5" fill="#10b981" />
                  <circle cx="190" cy="45" r="5" fill="#10b981" />
                  <circle cx="250" cy="35" r="5" fill="#10b981" />
                </svg>
              </div>
            </div>
          </div>

          {/* Standard Path */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs text-gray-500 uppercase tracking-wider">Balanced</div>
                <div className="text-xs bg-blue-100 text-blue-700 px-2.5 py-1 rounded-md font-medium">Safety #2</div>
              </div>
              <h3 className="text-xl mb-2 font-medium">Standard Path</h3>
              <p className="text-sm text-gray-600 mb-6 leading-relaxed">
                Routes balance route reliability and average safety indicators.
              </p>

              <div className="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">Duration</div>
                  <div className="text-2xl font-medium">15 min</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">SOS Coverage</div>
                  <div className="text-2xl font-medium">Partial</div>
                </div>
              </div>

              <div className="mb-6">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Passing Status</div>
                <div className="text-sm text-gray-600 leading-relaxed">
                  One or two weak-signal segment standard
                  lighting in traffic. Moderate emergency
                  vehicle coverage.
                </div>
              </div>

              <div className="bg-[#1a1a1a] rounded-lg p-6 h-36 flex items-center justify-center">
                <svg className="w-full h-full" viewBox="0 0 280 120">
                  <path
                    d="M 30,60 Q 90,40 140,60 Q 190,80 250,60"
                    fill="none"
                    stroke="#f59e0b"
                    strokeWidth="5"
                    strokeLinecap="round"
                  />
                  <circle cx="140" cy="60" r="6" fill="#f59e0b" />
                </svg>
              </div>
            </div>
          </div>

          {/* Direct Route */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs text-gray-500 uppercase tracking-wider">Fastest</div>
                <div className="text-xs bg-red-100 text-red-700 px-2.5 py-1 rounded-md font-medium">Safety #3</div>
              </div>
              <h3 className="text-xl mb-2 font-medium">Direct Route</h3>
              <p className="text-sm text-gray-600 mb-6 leading-relaxed">
                Fastest distance time, lighting and multiple
                indicator coverage reduce scores.
              </p>

              <div className="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">Duration</div>
                  <div className="text-2xl font-medium">14 min</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">SOS Coverage</div>
                  <div className="text-2xl font-medium">Deadzone</div>
                </div>
              </div>

              <div className="mb-6">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">SOS Deadzone Warning</div>
                <div className="text-sm text-gray-600 leading-relaxed">
                  Route to A faster, but includes a 30-mile no
                  service stretch. Emergency calling may be
                  delayed until coverage returns.
                </div>
              </div>

              <div className="bg-[#1a1a1a] rounded-lg p-6 h-36 flex items-center justify-center">
                <svg className="w-full h-full" viewBox="0 0 280 120">
                  <path
                    d="M 30,60 L 250,60"
                    fill="none"
                    stroke="#4b5563"
                    strokeWidth="2.5"
                    strokeLinecap="round"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Banner */}
        <div className="bg-white rounded-xl border border-gray-200 p-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Shield className="w-7 h-7 text-green-600 flex-shrink-0" />
            <div>
              <div className="text-base mb-1 font-medium">
                Well-lit Streets is the safest option tonight.
              </div>
              <div className="text-sm text-gray-600">
                It's slightly less SOS-deadzone path that adds just 4 minutes but avoids main safety hazards.
              </div>
            </div>
          </div>
          <div className="flex gap-3">
            <button className="px-5 py-2.5 border border-gray-300 bg-white rounded-lg text-sm whitespace-nowrap">
              Share trip log
            </button>
            <Link
              to="/safety-score"
              className="px-5 py-2.5 bg-black text-white rounded-lg text-sm whitespace-nowrap"
            >
              Start navigation
            </Link>
          </div>
        </div>
      </main>
    </div>
  );
}
