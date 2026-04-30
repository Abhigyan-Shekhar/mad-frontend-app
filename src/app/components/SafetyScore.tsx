import { Header } from "./Header";
import { AlertTriangle, AlertCircle } from "lucide-react";
import { Link } from "react-router";

export function SafetyScore() {
  return (
    <div className="min-h-screen bg-[#FAF9F6]">
      <Header currentPage="Safety Score" />

      <main className="max-w-[1400px] mx-auto px-8 py-12">
        <div className="grid grid-cols-[420px_1fr] gap-8">
          {/* Left Column */}
          <div>
            {/* Safety Score Card */}
            <div className="bg-white rounded-xl border border-gray-200 p-8 mb-6">
              <div className="text-xs text-gray-500 uppercase tracking-wider mb-3">Route score</div>
              <div className="text-[80px] leading-none mb-6">78</div>
              <p className="text-base text-gray-600 leading-relaxed mb-8">
                Moderately safe for night commute on MG Road Corridor.
              </p>

              <div className="grid grid-cols-3 gap-6 mb-8 pb-8 border-b border-gray-200">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Updated</div>
                  <div className="text-base font-medium">2 min ago</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Area</div>
                  <div className="text-base font-medium">MG Road</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Route</div>
                  <div className="text-base font-medium">Night</div>
                  <div className="text-sm text-gray-600">Commute</div>
                </div>
              </div>

              {/* Coverage Stats */}
              <div className="mb-8">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-4">Coverage stats</div>
                <p className="text-sm text-gray-600 leading-relaxed mb-6">
                  Calculates most of the route daytime layer. Long cross-mixed
                  distances can trigger on SOS dashboard warning but if road quality and
                  lighting coverage exceeds.
                </p>

                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Route indexed</span>
                    <span className="font-medium">100%</span>
                  </div>
                  <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div className="h-full bg-green-600 rounded-full" style={{ width: "100%" }}></div>
                  </div>
                </div>
              </div>

              {/* Warnings */}
              <div className="space-y-4">
                <div className="bg-orange-50 border border-orange-200 rounded-xl p-4 flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="text-sm font-medium mb-1">Route forecast</div>
                    <div className="text-sm text-gray-600 leading-relaxed">
                      Church Street predicts slow fragment path previous in this corridor and
                      expresses late arrival.
                    </div>
                  </div>
                </div>

                <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="text-sm font-medium mb-1">Recommendation action</div>
                    <div className="text-sm text-gray-600">
                      Choose the route with stronger light
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Metrics Grid */}
            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Potholes</div>
                <div className="text-3xl font-medium mb-2">9.4</div>
                <div className="text-sm text-gray-600 mb-3">Moderate potholes</div>
                <div className="text-xs text-gray-600 mb-3 leading-relaxed">
                  Pothole potholes mapped to (82%) in
                </div>
                <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div className="h-full bg-orange-500" style={{ width: "30%" }}></div>
                </div>
              </div>

              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Roadlights</div>
                <div className="text-3xl font-medium mb-2">7.6</div>
                <div className="text-sm text-gray-600 mb-3">Severity not standard</div>
                <div className="text-xs text-gray-600 mb-3 leading-relaxed">
                  Some roadlights missing at 2km east
                </div>
                <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div className="h-full bg-yellow-500" style={{ width: "35%" }}></div>
                </div>
              </div>

              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Theft</div>
                <div className="text-3xl font-medium mb-2">-</div>
                <div className="text-sm text-gray-600 mb-3">Three incidents</div>
                <div className="text-xs text-gray-600 mb-3 leading-relaxed">
                  Three vehicle theft, Still increases
                </div>
                <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div className="h-full bg-red-500" style={{ width: "33%" }}></div>
                </div>
              </div>
            </div>

            {/* How to read */}
            <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
              <div className="text-base font-medium mb-6">How to read this score</div>
              <div className="space-y-5">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium">Potholes reduce risk</span>
                    <span className="text-sm font-medium">30%</span>
                  </div>
                  <div className="text-sm text-gray-600 leading-relaxed">
                    Potholes rarely result deficits improve stability and reduced
                    incident probability.
                  </div>
                </div>

                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium">Streetlights improve</span>
                    <span className="text-sm font-medium">25%</span>
                  </div>
                  <div className="text-sm text-gray-600 leading-relaxed">
                    Better light coverage supports pedestrian exposure and
                    supports fewer risky events.
                  </div>
                </div>

                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium">Theft affects</span>
                    <span className="text-sm font-medium">20%</span>
                  </div>
                  <div className="text-sm text-gray-600 leading-relaxed">
                    Repeat incidents incidents increase lower trust
                    incidents per area. Still increases alert level.
                  </div>
                </div>
              </div>
            </div>

            {/* SOS Deadzone */}
            <div className="bg-white rounded-xl border border-gray-200 p-6">
              <div className="text-xs text-gray-500 uppercase tracking-wider mb-4">Emergency coverage level</div>
              <div className="text-base font-medium mb-6">SOS deadzone analysis</div>

              <div className="space-y-5 mb-6">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Threat density</div>
                  <div className="text-2xl font-medium">Low</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">No-service stretch</div>
                  <div className="text-2xl font-medium">0 (30 L)</div>
                  <div className="text-sm text-gray-600">3 km / mile</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Recommendation</div>
                  <div className="text-2xl font-medium">Avoid</div>
                  <div className="text-sm text-gray-600">30 miles</div>
                </div>
              </div>

              <p className="text-sm text-gray-600 leading-relaxed">
                This major route lacks SOS at stretches stretch. Cellular network is weak
                pressures making 8 KSA hazard, making it for better choice for night driving and road
                risks.
              </p>
            </div>

            <div className="bg-orange-50 border border-orange-200 rounded-xl p-4 mt-6">
              <div className="text-sm font-medium mb-1">Warning: active</div>
              <div className="text-sm text-gray-600">Flooding</div>
            </div>
          </div>

          {/* Right Column */}
          <div>
            {/* Map */}
            <div className="bg-white rounded-xl border border-gray-200 p-8 mb-6">
              <div className="bg-[#1a1a1a] rounded-xl overflow-hidden mb-6 h-96 flex items-center justify-center">
                <svg className="w-full h-full" viewBox="0 0 600 400">
                  <path
                    d="M 80,320 Q 150,250 220,200 Q 290,150 360,120 Q 430,90 520,60"
                    fill="none"
                    stroke="#10b981"
                    strokeWidth="5"
                    strokeLinecap="round"
                  />
                  <circle cx="80" cy="320" r="7" fill="#10b981" />
                  <circle cx="220" cy="200" r="7" fill="#10b981" />
                  <circle cx="360" cy="120" r="7" fill="#10b981" />
                  <circle cx="520" cy="60" r="7" fill="#10b981" />

                  {/* Markers */}
                  <g transform="translate(220, 190)">
                    <path d="M 0,-12 L 6,0 L 0,10 L -6,0 Z" fill="#10b981" />
                  </g>
                  <g transform="translate(360, 110)">
                    <path d="M 0,-12 L 6,0 L 0,10 L -6,0 Z" fill="#10b981" />
                  </g>
                  <g transform="translate(520, 50)">
                    <path d="M 0,-12 L 6,0 L 0,10 L -6,0 Z" fill="#10b981" />
                  </g>
                </svg>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded-xl p-5">
                <div className="text-base font-medium mb-2">Route forecast</div>
                <p className="text-sm text-gray-600 leading-relaxed">
                  Church Street predicts low fragment path previous in this corridor and
                  expresses late arrival.
                </p>
              </div>
            </div>

            {/* Recommendation */}
            <div className="bg-white rounded-xl border border-gray-200 p-8">
              <div className="text-2xl mb-4">Choose the route with stronger light</div>
              <p className="text-base text-gray-600 mb-8 leading-relaxed">
                Higher the better corridor, avoid the 4th side area after the native calls and
                choose whichever alternative reference calling late fields.
              </p>

              <div className="flex gap-4 mb-10">
                <Link
                  to="/guardian-mode"
                  className="flex-1 px-6 py-3 bg-black text-white rounded-lg text-base text-center"
                >
                  View safest route
                </Link>
                <button className="flex-1 px-6 py-3 border border-gray-300 bg-white rounded-lg text-base">
                  Share report
                </button>
              </div>

              <div className="pt-8 border-t border-gray-200">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-5">Last 7 days</div>
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Potholes reported</span>
                    <span className="text-blue-600 font-medium">+5</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Lights active</span>
                    <span className="font-medium">73%</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Theft incidents</span>
                    <span className="font-medium">3</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
