//
//  WeatherSceneTests.swift
//  BreezyUnitsTests
//
//  These pin colours and counts to values read out of the upstream resources. A port
//  that "looks about right" is the defect this file exists to prevent: the gradient
//  stops and the particle counts are data, so they can be asserted exactly.
//

import Testing
@testable import BreezyUnits

@Suite("Weather scene")
struct WeatherSceneTests {
    private func hex(_ colour: RGB) -> String {
        String(
            format: "%02X%02X%02X",
            Int(colour.red.rounded()), Int(colour.green.rounded()), Int(colour.blue.rounded())
        )
    }

    @Test("every light gradient matches its upstream drawable")
    func lightGradients() {
        // weather_background_*.xml, area by area, as grepped from the repository.
        let expected: [(WeatherKind, Bool, String, String, String)] = [
            (.clear, true, "FFBA5E", "FFC67E", "FFF0E2"),
            (.clear, false, "171D52", "3F4DBA", "5E68BD"),
            (.cloud, true, "64DBFF", "D6DEE0", "E2F0F6"),
            (.cloudy, true, "AFBCC7", "D2D6DB", "EBEFF8"),
            (.fog, true, "A2C3FF", "B3AFD1", "E7BEB0"),
            (.haze, true, "FFDDA1", "D1C3AF", "B5E8EF"),
            (.rain, true, "97B6D1", "A6BBCE", "97A8D7"),
            (.sleet, true, "B4D3ED", "C5D2DC", "ADC3DE"),
            (.snow, true, "93A2AD", "E3E7EB", "EDF2F6"),
            (.hail, true, "DDF7FF", "E1E5E9", "A0AFC1"),
            (.thunder, true, "C697D7", "C1A3CE", "AB90DB"),
            (.thunderstorm, true, "C697D7", "C1A3CE", "AB90DB"),
            (.wind, true, "96D0A3", "DFFAE7", "E8F4EE")
        ]
        for (kind, daylight, start, center, end) in expected {
            let stops = WeatherScene.gradient(kind, daylight: daylight, darkMode: false)
            #expect(hex(stops.start) == start, "\(kind) start")
            #expect(hex(stops.center) == center, "\(kind) center")
            #expect(hex(stops.end) == end, "\(kind) end")
        }
    }

    @Test("every dark gradient matches its -night override")
    func darkGradients() {
        let expected: [(WeatherKind, Bool, String, String, String)] = [
            // The clear-day asset has a night variant; the clear-night asset does not.
            (.clear, true, "592B19", "CC6143", "D18268"),
            (.clear, false, "171D52", "3F4DBA", "5E68BD"),
            (.cloud, true, "1C2F75", "585D6D", "747B99"),
            (.cloudy, true, "23262C", "525D66", "6B8394"),
            (.fog, true, "131B45", "2A5476", "918EAF"),
            (.haze, true, "4D3314", "755125", "C5AF9D"),
            (.rain, true, "233361", "2F4997", "252731"),
            (.sleet, true, "23306B", "3549A4", "23262F"),
            (.snow, true, "353A47", "455762", "414F83"),
            (.hail, true, "335A7E", "435A6F", "303742"),
            (.thunder, true, "2F2B38", "50406D", "2C1C4D"),
            (.wind, true, "313E3A", "529B73", "638170")
        ]
        for (kind, daylight, start, center, end) in expected {
            let stops = WeatherScene.gradient(kind, daylight: daylight, darkMode: true)
            #expect(hex(stops.start) == start, "\(kind) start")
            #expect(hex(stops.center) == center, "\(kind) center")
            #expect(hex(stops.end) == end, "\(kind) end")
        }
    }

    @Test("the cloud table has the upstream counts, alphas and periods")
    func cloudTable() {
        #expect(WeatherScene.fogLayers(haze: false, daylight: true, darkMode: false).count == 9)
        #expect(WeatherScene.fogLayers(haze: true, daylight: true, darkMode: false).count == 9)
        #expect(WeatherScene.cloudyLayers(thunder: false, daylight: true, darkMode: false).count == 6)
        #expect(WeatherScene.cloudLayers(daylight: true, darkMode: false).count == 6)

        // TYPE_CLOUD carries two alphas; the weather kinds with a "sky" carry 0.3.
        let cloud = WeatherScene.cloudLayers(daylight: true, darkMode: false)
        #expect(Set(cloud.map(\.alpha)) == [0.10, 0.40])
        let cloudy = WeatherScene.cloudyLayers(thunder: false, daylight: true, darkMode: false)
        #expect(Set(cloudy.map(\.alpha)) == [0.3])

        // A circle breathes to peakScale at the half cycle and back to radius at the end.
        let layer = cloudy[0]
        #expect(abs(layer.radius(at: 0) - layer.radius) < 0.0001)
        #expect(abs(layer.radius(at: layer.period / 2) - layer.radius * layer.peakScale) < 0.0001)
        #expect(abs(layer.radius(at: layer.period) - layer.radius) < 0.0001)
    }

    @Test("the sun is three rotated squares with upstream alphas and speeds")
    func sunTable() {
        #expect(WeatherScene.sunRays.count == 3)
        #expect(WeatherScene.sunRays.map(\.alpha) == [0.16, 0.08, 0.04])
        #expect(WeatherScene.sunRays.map(\.quarterTurnSeconds) == [3, 4, 5])
        #expect(abs(WeatherScene.sunPositionRatio - 0.5) < 0.0001)
    }

    @Test("particle counts match the implementors' COUNT constants")
    func particleCounts() {
        #expect(WeatherScene.particleCount(.rain) == 75)
        #expect(WeatherScene.particleCount(.thunderstorm) == 75)
        #expect(WeatherScene.particleCount(.sleet) == 45)
        #expect(WeatherScene.particleCount(.snow) == 50)
        #expect(WeatherScene.particleCount(.hail) == 51)
        #expect(WeatherScene.particleCount(.wind) == 160)
    }

    @Test("the same seed gives the same scene, and particles stay in bounds")
    func determinism() {
        let width = 393.0
        let height = 852.0
        for kind: WeatherScene.Precipitation in [.rain, .sleet, .snow, .hail, .wind, .thunderstorm] {
            let a = WeatherScene.particles(kind, daylight: true, width: width, height: height, seed: 7)
            let b = WeatherScene.particles(kind, daylight: true, width: width, height: height, seed: 7)
            #expect(a == b, "\(kind) is not deterministic")
            #expect(a.count == WeatherScene.particleCount(kind))

            for particle in a {
                #expect(particle.speed > 0)
                #expect(particle.length > 0)
                #expect(particle.thickness > 0)
                // A wrapped position is never further out than one particle length.
                for seconds in [0.0, 1.0, 9.5, 61.0] {
                    let along = particle.position(at: seconds, span: height)
                    #expect(along >= -particle.length - 0.001)
                    #expect(along <= height + 0.001)
                }
            }
        }
    }

    @Test("night stars are deterministic and fade in and out")
    func stars() {
        let a = WeatherScene.stars(count: 50, width: 393, height: 852, seed: 3)
        let b = WeatherScene.stars(count: 50, width: 393, height: 852, seed: 3)
        #expect(a.count == 50)
        #expect(a == b)
        let star = a[0]
        #expect(abs(star.alpha(at: 0)) < 0.0001)
        #expect(abs(star.alpha(at: star.period / 2) - 1) < 0.0001)
        #expect(abs(star.alpha(at: star.period)) < 0.0001)
        // Colours cycle through the upstream palette, by index.
        let palette = a.map { hex($0.colour) }
        #expect(Set(palette).count >= 5)
    }
}
