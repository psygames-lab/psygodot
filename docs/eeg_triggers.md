# EEG markers and hardware triggers

Status: design for a future device integration. No physical trigger driver, LSL
outlet, serial-port dependency, or additional runtime worker is implemented by
the offline HED work.

## What exists today

The editable [event catalog](../analysis/EVENT_CATALOG.md) defines each event's
matching conditions, optional study code, and offline HED interpretation in one
place. Its generator produces a small runtime marker configuration without HED
content. `trigger_manager.gd` matches event type/tag and any payload conditions
from that configuration, including distinctions such as manual versus replay.
The runtime's
`log_event_with_marker()` records a second JSONL row with `event_type=marker`,
`event_tag=marker_sent`, and `payload.marker.driver=mock`. Its timestamp equals
the source event timestamp. Despite the historical name `marker_sent`, this is
only a simulated software record: no device is contacted and there is no send
time or EEG acknowledgement. Without configured marker rules, or when a game
uses ordinary event logging rather than marker simulation, no marker rows are
generated. Both example games leave simulation off unless explicitly requested.

HED mappings must not interpret these mock records as physical trigger edges.
They can explicitly exclude them with that reason, or retain them as simulated
controller records. The source-event link remains useful for analysis.

## Separate the three responsibilities

1. The game records what happened and when it observed it. Game mechanics and
   event names stay in the game adapter.
2. A study chooses which source events need markers and their numeric codes.
   Codes are experiment assignments, not HED tags or fixed framework constants.
3. A device driver implements the selected equipment's transport and pulse
   protocol. The same event and code can be sent through different drivers
   without changing game logic or its HED mapping.

Serial and parallel connections are common approaches, but a connector name
does not specify a universal EEG protocol. Brain Products provides USB trigger
hardware exposing a serial interface. BioSemi's USB Trigger Interface also
appears as a serial port while producing parallel trigger bits; its documented
interface supplies its own pulse duration and automatic reset. These are
device-specific behaviors, not defaults for every amplifier.
[Brain Products TriggerBox](https://www.brainproducts.com/solutions/triggerbox/),
[BioSemi USB Trigger Interface](https://www.biosemi.com/faq/USB%20Trigger%20interface%20cable.htm).

## Proposed first implementation

Implement one selected device after its model and protocol are known, plus a
fake driver for deterministic tests. A driver needs only initialization,
send-code, and close/reset operations. Do not build a plugin registry or ship
untested generic serial/parallel drivers. Initialize outside active play.

The sending path must be independent of the JSONL writer. Waiting for disk
batching before emitting a trigger would add unrelated delay. A small dedicated
sender queue can keep potentially blocking device calls off the game thread;
it also introduces queue and scheduler delay that must be measured. A separate
thread is not a precision guarantee. Never sleep on the game thread to hold a
TTL pulse or wait for an acknowledgement.

For a future request, preserve the source event ID, its observed Godot
timestamp, code, and driver identity. Return whether the request was accepted.
A full queue must report rejection and increment a counter; never silently
drop, merge, overwrite, or retry a trigger. A late retry could create a second
edge at the wrong time. Request admission is not successful transmission.

The current helper does not create a mock marker if its source event was
rejected by the event logger. A real-driver implementation must make this
policy explicit and report such suppressed requests; otherwise a logger
overflow could silently become missing EEG triggers. Accepted logger records
can also later fail to persist, so retain transport counters independently of
recording completeness.

Device-specific setup must establish supported codes/bit width, idle state,
edge polarity, pulse duration, minimum inter-trigger gap, and whether hardware
or software resets the output. Reset-to-zero is common but cannot be assumed
for all devices. Serial baud rate and encoding, native parallel-port drivers,
and any acknowledgement format belong to the selected driver. Shutdown must
settle or explicitly cancel pending requests and restore the required idle
state. A session must not claim complete trigger delivery while requests remain
unresolved. Waiting for teardown is allowed; waiting during active play is not.

## Keep observations and timing claims distinct

The planned transport audit should record these fields when they are known:

| Field | Meaning |
| --- | --- |
| `source_event_id` | Link to the original game event; combine with session ID across files |
| `source_timestamp_usec` | Game's observation time in the Godot clock |
| `requested_timestamp_usec` | Time the software requested transport |
| `send_started_timestamp_usec` | Worker time immediately before calling the driver |
| `send_returned_timestamp_usec` | Worker time immediately after the driver call returns |
| `code`, `driver` | Study code and concrete transport identity |
| `status` | Explicit accepted, rejected, driver-returned, failed, cancelled, or simulated result |

The names above describe a proposed audit contract, not fields already emitted
by the current mock implementation. Store stable device configuration and clock
definitions once in session metadata. Result records collected later must keep
their source timestamps as payload fields rather than backdating new JSONL
rows and breaking the recorder's time order.

`send_started - requested` measures queue delay. A successful driver return
only establishes the meaning promised by that driver/API; it does not prove an
electrical edge or EEG acquisition. Only record an EEG-observed time/sample
when the EEG data or a documented device acknowledgement actually supplies it,
with that clock and evidence identified. A trigger code alone is not a unique
event ID: repeated codes require ordered matching and loss detection.

Godot timestamps do not measure physical screen or sound onset. End-to-end
validation needs a recorded trigger channel and, where the study requires it,
a photodiode or audio loopback. Measure latency, jitter, missed/extra edges,
consecutive identical codes, reset behavior, and frame times under a realistic
event burst before making a timing claim.

## LSL and HED are separate layers

LSL is a possible software-marker backend, not a TTL replacement for every EEG
system. Its timestamps use the LSL clock. Do not pass
`Time.get_ticks_usec() / 1e6` directly as an LSL timestamp merely because both
clocks are monotonic. An implementation needs an explicit clock mapping or
LSL-side timestamping with source time retained separately. Preserve the clock
pair measurements and synchronization metadata needed to estimate offsets and
drift. [LSL time synchronization](https://labstreaminglayer.readthedocs.io/info/time_synchronization.html).

HED conversion stays offline and does not send markers. Retain trigger codes,
source-event links, status, and measured transport times as ordinary TSV
columns with descriptions. Only apply HED semantics supported by the actual
observation. The game-session origin remains the event export timebase until
a separate EEG alignment step establishes the EEG recording origin. Never
replace event onset with a guessed physical trigger time or silently subtract
an assumed constant transport delay.
