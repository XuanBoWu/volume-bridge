import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

var slider = VolumeSliderState()
slider.refresh(volume: 100, uid: "monitor", enabled: true)
slider.beginTracking()
slider.userChanged(to: 60)
slider.refresh(volume: 100, uid: "monitor", enabled: true)
check(slider.value == 60, "Stale 100% snapshot must not reset an active drag")
slider.userChanged(to: 20)
slider.endTracking()
slider.refresh(volume: 60, uid: "monitor", enabled: true)
check(slider.value == 20, "Mouse-up must retain latest value until acknowledged")
slider.refresh(volume: 20, uid: "monitor", enabled: true)
check(slider.pendingValue == nil, "Latest acknowledgement must release pending value")
slider.refresh(volume: 30, uid: "monitor", enabled: true)
check(slider.value == 30, "Idle slider must still follow external changes")

slider.beginTracking()
slider.userChanged(to: 0)
slider.refresh(volume: 30, uid: "monitor", enabled: true)
slider.userChanged(to: 75.123456789)
slider.endTracking()
slider.refresh(volume: 0, uid: "monitor", enabled: true)
check(slider.value == Double(Float(75.123456789)), "Leaving zero must survive stale snapshot")
slider.refresh(volume: Double(Float(75.123456789)), uid: "monitor", enabled: true)
check(slider.pendingValue == nil, "Fractional value must match Float acknowledgement")

slider.userChanged(to: 100)
slider.refresh(volume: 45, uid: "another-monitor", enabled: true)
check(slider.value == 45 && slider.pendingValue == nil, "Pending value must not cross devices")
slider.userChanged(to: 10)
slider.refresh(volume: 45, uid: "another-monitor", enabled: false)
check(slider.value == 45 && slider.pendingValue == nil, "Bypass must clear pending UI input")
slider.userChanged(to: 60)
slider.discardPending()
slider.refresh(volume: 66.25, uid: "another-monitor", enabled: true)
check(slider.value == 66.25, "A later media key must take over from pending mouse input")
print("PASS slider regression: 100% → lower, stale acknowledgements, zero, fractional values, device switch and bypass")
