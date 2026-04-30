import { Header } from "./Header";
import { MapPin, AlertTriangle, Radio, ChevronRight } from "lucide-react";

export function GuardianMode() {
  return (
    <div className="min-h-screen bg-[#FAF9F6]">
      <Header currentPage="Guardian Mode" />

      <main className="max-w-[1400px] mx-auto px-8 py-12">
        <div className="grid grid-cols-[1fr_420px] gap-8">
          {/* Left Column */}
          <div>
            {/* Trip Header */}
            <div className="bg-white rounded-xl border border-gray-200 p-8 mb-6">
              <div className="flex items-start justify-between mb-8">
                <div>
                  <div className="text-sm text-gray-500 mb-2">Tracked trip</div>
                  <h2 className="text-3xl font-medium">Aarav to City Hospital Gate 2</h2>
                </div>
                <div className="flex items-center gap-2 bg-green-50 text-green-700 px-4 py-2 rounded-full text-sm font-medium">
                  <div className="w-2.5 h-2.5 bg-green-600 rounded-full animate-pulse"></div>
                  Guardian watching
                </div>
              </div>

              {/* Map */}
              <div className="bg-gray-100 rounded-xl mb-8 h-[480px] relative overflow-hidden">
                <svg className="w-full h-full" viewBox="0 0 800 480">
                  {/* Grid background */}
                  <defs>
                    <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                      <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#e5e7eb" strokeWidth="0.5"/>
                    </pattern>
                  </defs>
                  <rect width="800" height="480" fill="url(#grid)"/>

                  {/* Route path - dashed upcoming */}
                  <path
                    d="M 120,400 Q 180,350 240,320 Q 300,290 360,260 Q 420,230 480,210 Q 540,190 600,175 Q 660,160 720,150"
                    fill="none"
                    stroke="#93c5fd"
                    strokeWidth="3"
                    strokeDasharray="8,8"
                    opacity="0.6"
                  />

                  {/* Active path - solid */}
                  <path
                    d="M 120,400 Q 180,350 240,320 Q 300,290 360,260"
                    fill="none"
                    stroke="#3b82f6"
                    strokeWidth="5"
                    strokeLinecap="round"
                  />

                  {/* Start marker */}
                  <circle cx="120" cy="400" r="10" fill="#3b82f6" stroke="white" strokeWidth="3" />
                  <text x="120" y="430" fontSize="12" textAnchor="middle" fontWeight="500" fill="#374151">Start</text>

                  {/* Current position - animated */}
                  <circle cx="360" cy="260" r="12" fill="#10b981" stroke="white" strokeWidth="4">
                    <animate attributeName="r" values="12;16;12" dur="2s" repeatCount="indefinite" />
                  </circle>
                  <circle cx="360" cy="260" r="24" fill="#10b981" opacity="0.2">
                    <animate attributeName="r" values="24;32;24" dur="2s" repeatCount="indefinite" />
                  </circle>

                  {/* Accident notification */}
                  <g transform="translate(480, 210)">
                    <circle r="28" fill="#ef4444" opacity="0.15" />
                    <circle r="16" fill="#ef4444" />
                    <text x="0" y="6" fontSize="14" fontWeight="bold" fill="white" textAnchor="middle">!</text>
                  </g>
                  <rect x="510" y="195" width="180" height="70" rx="8" fill="white" stroke="#e5e7eb" strokeWidth="1.5" filter="drop-shadow(0 2px 8px rgba(0,0,0,0.08))"/>
                  <text x="520" y="215" fontSize="11" fontWeight="600" fill="#374151">Accident notification</text>
                  <text x="520" y="230" fontSize="10" fill="#6b7280">Minor crash reported 120</text>
                  <text x="520" y="243" fontSize="10" fill="#6b7280">m ahead. ETA may</text>
                  <text x="520" y="256" fontSize="10" fill="#6b7280">increase by 4 minutes if...</text>

                  {/* SOS deadzone warning */}
                  <g transform="translate(600, 175)">
                    <circle r="28" fill="#f59e0b" opacity="0.15" />
                    <circle r="16" fill="#f59e0b" />
                    <path d="M -4,-4 L 4,4 M 4,-4 L -4,4" stroke="white" strokeWidth="2.5" strokeLinecap="round" />
                  </g>
                  <rect x="180" y="280" width="180" height="70" rx="8" fill="white" stroke="#e5e7eb" strokeWidth="1.5" filter="drop-shadow(0 2px 8px rgba(0,0,0,0.08))"/>
                  <text x="190" y="300" fontSize="11" fontWeight="600" fill="#374151">SOS deadzone warning</text>
                  <text x="190" y="315" fontSize="10" fill="#6b7280">Cell coverage may drop</text>
                  <text x="190" y="328" fontSize="10" fill="#6b7280">for the next 30 miles.</text>
                  <text x="190" y="341" fontSize="10" fill="#6b7280">Emergency calls could...</text>

                  {/* Destination marker */}
                  <circle cx="720" cy="150" r="10" fill="#ef4444" stroke="white" strokeWidth="3" />
                  <text x="720" y="135" fontSize="12" textAnchor="middle" fontWeight="500" fill="#374151">Destination</text>
                  <text x="720" y="180" fontSize="11" textAnchor="middle" fill="#6b7280">City Hospital Gate 2</text>
                </svg>
              </div>

              {/* Trip Stats */}
              <div className="grid grid-cols-4 gap-8">
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Started</div>
                  <div className="text-2xl font-medium">8:03 PM</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Time taken</div>
                  <div className="text-2xl font-medium">27 min</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Time left</div>
                  <div className="text-2xl font-medium text-blue-600">12 min</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 uppercase tracking-wider mb-2">Arrival</div>
                  <div className="text-2xl font-medium">8:42 PM</div>
                </div>
              </div>
            </div>

            {/* Feature Cards */}
            <div className="grid grid-cols-3 gap-6">
              <div className="bg-white rounded-xl border border-gray-200 p-6">
                <div className="flex items-center justify-center w-14 h-14 bg-orange-100 rounded-full mb-4">
                  <AlertTriangle className="w-7 h-7 text-orange-600" />
                </div>
                <div className="text-base font-medium mb-2">Accident alerts on map</div>
                <p className="text-sm text-gray-600 leading-relaxed">
                  Incidents appear exactly on the route, with a short explanation and delay estimate.
                </p>
              </div>

              <div className="bg-white rounded-xl border border-gray-200 p-6">
                <div className="flex items-center justify-center w-14 h-14 bg-blue-100 rounded-full mb-4">
                  <svg className="w-7 h-7 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                </div>
                <div className="text-base font-medium mb-2">Guardian mode</div>
                <p className="text-sm text-gray-600 leading-relaxed">
                  A trusted person can monitor the route, status, and alerts without clutter.
                </p>
              </div>

              <div className="bg-white rounded-xl border border-gray-200 p-6">
                <div className="flex items-center justify-center w-14 h-14 bg-green-100 rounded-full mb-4">
                  <svg className="w-7 h-7 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div className="text-base font-medium mb-2">Time calculation</div>
                <p className="text-sm text-gray-600 leading-relaxed">
                  Time taken so far, remaining time, and final arrival are visible at a glance.
                </p>
              </div>
            </div>
          </div>

          {/* Right Column */}
          <div>
            {/* Guardian Summary */}
            <div className="bg-white rounded-xl border border-gray-200 p-8 mb-6">
              <div className="text-xs text-gray-500 uppercase tracking-wider mb-4">Guardian Summary</div>
              <h3 className="text-2xl font-medium mb-4">Trip status is stable</h3>
              <p className="text-base text-gray-600 mb-8 leading-relaxed">
                Aarav is moving on the planned route. One accident alert
                is active, but the guardian can <span className="text-blue-600">still see</span> a safe alternate
                option.
              </p>

              <div className="space-y-5 mb-8">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Current speed</span>
                  <span className="text-base font-medium">22 km/h</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Distance remaining</span>
                  <span className="text-base font-medium">2.8 km</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Route deviation</span>
                  <span className="text-base font-medium text-blue-600">No deviation</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-600">Cell coverage</span>
                  <span className="text-base font-medium text-orange-600">Deadzone ahead</span>
                </div>
              </div>

              <div className="flex gap-3">
                <button className="flex-1 px-5 py-3 bg-black text-white rounded-lg text-sm font-medium">
                  Call traveler
                </button>
                <button className="flex-1 px-5 py-3 border border-gray-300 bg-white rounded-lg text-sm font-medium">
                  Message
                </button>
              </div>
            </div>

            {/* Live Alerts */}
            <div className="bg-white rounded-xl border border-gray-200 p-8">
              <div className="flex items-center justify-between mb-6">
                <div className="text-xs text-gray-500 uppercase tracking-wider">Live Alerts</div>
                <div className="text-sm text-orange-600 font-medium">2 active</div>
              </div>

              <div className="text-base font-medium mb-6">Current notifications</div>

              <div className="space-y-4 mb-8">
                <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <MapPin className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <div className="text-sm font-medium mb-1.5">Accident ahead</div>
                      <p className="text-sm text-gray-600 leading-relaxed">
                        Crash near Richmond Circle. The app recalculated arrival from 8:38 PM to 8:42 PM.
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <svg className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                    </svg>
                    <div className="flex-1">
                      <div className="text-sm font-medium mb-1.5">Alternate route available</div>
                      <p className="text-sm text-gray-600 leading-relaxed">
                        Adds 3 minutes but avoids the blocked road section and keeps trip tracking uninterrupted.
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-orange-50 border border-orange-200 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <Radio className="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <div className="text-sm font-medium mb-1.5">Coverage loss expected</div>
                      <p className="text-sm text-gray-600 leading-relaxed">
                        The next segment includes a 30-mile no-service stretch. Guardian alerts may be delayed until coverage returns.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Guardian Actions */}
              <div className="border-t border-gray-200 pt-6">
                <div className="text-xs text-gray-500 uppercase tracking-wider mb-4">Guardian Actions</div>
                <div className="space-y-3">
                  <button className="w-full flex items-center justify-between p-4 rounded-lg hover:bg-gray-50 text-left transition-colors">
                    <span className="text-sm font-medium">Open full trip history</span>
                    <ChevronRight className="w-5 h-5 text-gray-400" />
                  </button>
                  <button className="w-full flex items-center justify-between p-4 rounded-lg hover:bg-gray-50 text-left transition-colors">
                    <span className="text-sm font-medium">Escalate to emergency contact</span>
                    <ChevronRight className="w-5 h-5 text-gray-400" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
