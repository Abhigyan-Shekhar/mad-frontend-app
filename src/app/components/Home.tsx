import { Header } from "./Header";
import { MapPin, AlertTriangle } from "lucide-react";
import { Link } from "react-router";

export function Home() {
  return (
    <div className="min-h-screen bg-[#FAF9F6]">
      <Header />

      <main className="max-w-[1400px] mx-auto px-8 py-16">
        <div className="grid grid-cols-2 gap-16">
          {/* Left Column */}
          <div className="pr-8">
            <div className="flex items-center gap-2 mb-6">
              <MapPin className="w-4 h-4" />
              <span className="text-sm">Not just any route</span>
            </div>

            <h1 className="text-[56px] leading-[1.1] mb-8">
              Not the safest route,<br />
              not only the fastest<br />
              one.
            </h1>

            <p className="text-base text-gray-600 mb-10 max-w-[480px] leading-relaxed">
              Navigate safely in cities and suburbs mobile using that
              avoid high-risk areas by lighting, road quality, incidents, and
              emergency access.
            </p>

            <div className="flex gap-4 mb-16">
              <Link
                to="/plan-journey"
                className="px-7 py-3 bg-black text-white rounded-md text-sm"
              >
                Get started
              </Link>
              <button className="px-7 py-3 border border-gray-300 bg-white rounded-md text-sm">
                Continue anonymously
              </button>
            </div>

            {/* Stats */}
            <div className="flex gap-16 mb-12">
              <div>
                <div className="text-[11px] text-gray-500 uppercase tracking-wider mb-2">
                  Trusted by
                </div>
                <div className="text-3xl mb-1">1,240</div>
                <div className="text-sm text-gray-600">users</div>
              </div>
              <div>
                <div className="text-[11px] text-gray-500 uppercase tracking-wider mb-2">
                  Available
                </div>
                <div className="text-3xl mb-1">24/7</div>
                <div className="text-sm text-gray-600">support</div>
              </div>
              <div>
                <div className="text-[11px] text-gray-500 uppercase tracking-wider mb-2">
                  Perfect for
                </div>
                <div className="text-3xl mb-1">Solo</div>
                <div className="text-sm text-gray-600">travel</div>
              </div>
            </div>

            {/* Warning Alert */}
            <div className="bg-red-50 border border-red-200 rounded-xl p-5 flex gap-4">
              <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
              <div>
                <div className="text-sm mb-2">
                  <span className="font-medium">New: SOS deadzone warning</span>
                </div>
                <div className="text-sm text-gray-600 leading-relaxed">
                  SafeRoute can flag long stretches with weak or zero cell
                  coverage so you know when flagging services may be
                  unavailable before you start a journey.
                </div>
              </div>
            </div>
          </div>

          {/* Right Column - Map Section */}
          <div>
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
              <div className="flex items-start justify-between mb-6">
                <div>
                  <div className="text-sm text-green-600 mb-2 flex items-center gap-2">
                    <div className="w-2 h-2 bg-green-600 rounded-full"></div>
                    Monitoring
                  </div>
                  <div className="text-2xl mb-3">Sentinel protocol active</div>
                  <p className="text-sm text-gray-600 leading-relaxed max-w-md">
                    Your area has active lighting coverage, secure traffic flow,
                    and reliable mobile network service.
                  </p>
                </div>
              </div>

              {/* Map Placeholder */}
              <div className="mb-6 rounded-xl overflow-hidden bg-gradient-to-br from-green-100 via-emerald-50 to-yellow-50 relative h-[320px]">
                <svg className="w-full h-full" viewBox="0 0 400 320">
                  {/* Map grid lines */}
                  <line x1="0" y1="80" x2="400" y2="80" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>
                  <line x1="0" y1="160" x2="400" y2="160" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>
                  <line x1="0" y1="240" x2="400" y2="240" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>
                  <line x1="100" y1="0" x2="100" y2="320" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>
                  <line x1="200" y1="0" x2="200" y2="320" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>
                  <line x1="300" y1="0" x2="300" y2="320" stroke="#d1d5db" strokeWidth="1" opacity="0.3"/>

                  {/* Route path */}
                  <path
                    d="M 60,250 Q 100,200 150,180 Q 200,160 250,140 Q 300,120 340,100"
                    fill="none"
                    stroke="#ef4444"
                    strokeWidth="4"
                    strokeLinecap="round"
                  />

                  {/* Location markers */}
                  <circle cx="60" cy="250" r="6" fill="#ef4444" />
                  <circle cx="150" cy="180" r="6" fill="#ef4444" />
                  <circle cx="250" cy="140" r="6" fill="#ef4444" />
                  <circle cx="340" cy="100" r="6" fill="#ef4444" />
                </svg>
              </div>

              {/* Map Features */}
              <div className="grid grid-cols-2 gap-6 mb-6 pb-6 border-b border-gray-200">
                <div>
                  <div className="text-xs text-gray-500 mb-1.5">Safe route</div>
                  <div className="text-base font-medium mb-1">MG Road corridor</div>
                  <div className="text-sm text-gray-600">
                    Adequate street lighting, low incident rate
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-1.5">Guardian mode ready</div>
                  <div className="text-base font-medium mb-1">Share live location</div>
                  <div className="text-sm text-gray-600">
                    Share live tracking link with a trusted contact
                  </div>
                </div>
              </div>

              {/* Coverage needs routing */}
              <div className="flex items-start gap-3">
                <AlertTriangle className="w-5 h-5 text-orange-500 flex-shrink-0 mt-0.5" />
                <div>
                  <div className="text-base font-medium mb-1">Coverage needs routing</div>
                  <div className="text-sm text-gray-600 leading-relaxed">
                    Autos has one long stretch with spotty network
                    coverage, and might not provide near-real-time tracking data until coverage returns.
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
