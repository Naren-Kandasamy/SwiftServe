// ─── Hardcoded Venue: Grand Horizon Hotel ────────────────────────────────────
// Coordinates (x, y) are normalised 0.0–1.0 relative to the canvas size.
// A room at (0.5, 0.5) appears dead-centre. Adjust values to match a real floor plan.
// Any guest-selected room maps directly to its pin coordinate on the Dashboard map.

class VenueConfig {
  static const String venueName = 'Grand Horizon Hotel';
  static const int totalFloors = 3;

  /// Returns the floors available as dropdown strings, e.g. ["1", "2", "3"]
  static List<String> get floors => List.generate(totalFloors, (i) => '${i + 1}');

  /// Returns all rooms on a given floor as their labels, e.g. ["Room 101", "Lobby", ...]
  static List<String> roomsForFloor(String floor) {
    final data = _layout[floor];
    if (data == null) return [];
    return data.keys.toList();
  }

  /// Returns the (x, y) canvas coordinate for a given floor+room.
  /// Falls back to (0.5, 0.5) centre if the room is not listed.
  static (double, double) coordinateFor(String floor, String room) {
    final coord = _layout[floor]?[room];
    if (coord == null) return (0.5, 0.5);
    return (coord[0], coord[1]);
  }

  // ─── Room Layout ─────────────────────────────────────────────────────────
  // Format: { 'room label': [x, y] }
  //   x: 0.0 = left edge, 1.0 = right edge
  //   y: 0.0 = top edge,  1.0 = bottom edge
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, Map<String, List<double>>> _layout = {
    '1': {
      'Lobby':            [0.50, 0.88],
      'Front Desk':       [0.30, 0.78],
      'Concierge':        [0.70, 0.78],
      'Room 101':         [0.12, 0.40],
      'Room 102':         [0.12, 0.55],
      'Room 103':         [0.12, 0.70],
      'Room 104':         [0.88, 0.40],
      'Room 105':         [0.88, 0.55],
      'Restaurant':       [0.50, 0.52],
      'Bar & Lounge':     [0.50, 0.35],
      'Gym':              [0.25, 0.20],
      'Pool / Spa':       [0.75, 0.20],
      'Stairwell A':      [0.08, 0.20],
      'Stairwell B':      [0.92, 0.20],
      'Elevator':         [0.50, 0.20],
      'Staff Office':     [0.18, 0.88],
      'Storage':          [0.82, 0.88],
    },
    '2': {
      'Room 201':         [0.12, 0.20],
      'Room 202':         [0.12, 0.37],
      'Room 203':         [0.12, 0.54],
      'Room 204':         [0.12, 0.71],
      'Room 205':         [0.38, 0.20],
      'Room 206':         [0.38, 0.37],
      'Room 207':         [0.38, 0.54],
      'Room 208':         [0.38, 0.71],
      'Room 209':         [0.62, 0.20],
      'Room 210':         [0.62, 0.37],
      'Room 211':         [0.62, 0.54],
      'Room 212':         [0.62, 0.71],
      'Room 213':         [0.88, 0.20],
      'Room 214':         [0.88, 0.37],
      'Room 215':         [0.88, 0.54],
      'Corridor North':   [0.50, 0.12],
      'Corridor South':   [0.50, 0.88],
      'Stairwell A':      [0.05, 0.50],
      'Stairwell B':      [0.95, 0.50],
      'Elevator':         [0.50, 0.50],
      'Laundry Room':     [0.20, 0.88],
      'Ice Machine':      [0.80, 0.88],
      'Vending Area':     [0.50, 0.78],
    },
    '3': {
      'Room 301':         [0.12, 0.20],
      'Room 302':         [0.12, 0.37],
      'Room 303':         [0.12, 0.54],
      'Room 304':         [0.12, 0.71],
      'Room 305':         [0.38, 0.20],
      'Room 306':         [0.38, 0.37],
      'Suite 307':        [0.38, 0.54],
      'Suite 308':        [0.62, 0.37],
      'Suite 309':        [0.62, 0.54],
      'Room 310':         [0.88, 0.20],
      'Room 311':         [0.88, 0.37],
      'Room 312':         [0.88, 0.54],
      'Room 313':         [0.88, 0.71],
      'Penthouse':        [0.50, 0.30],
      'Conference Room':  [0.50, 0.60],
      'Business Lounge':  [0.50, 0.78],
      'Corridor North':   [0.50, 0.12],
      'Stairwell A':      [0.05, 0.50],
      'Stairwell B':      [0.95, 0.50],
      'Elevator':         [0.50, 0.50],
    },
  };
}
