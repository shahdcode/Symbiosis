from pathlib import Path

path = Path('D:/Symbiosis/backend/app/core/scheduler.py')
text = path.read_text(encoding='utf-8')
old = '''        water_cmds = []
        for plant_id, ml in decision.water_allocations.items():
            actuate_water(plant_id, ml)
            _resource_agent.consume_water(ml)
            water_cmds.append({"plant": plant_id, "ml": round(ml, 1)})
'''
new = '''        water_cmds = []
        for plant_id, ml in decision.water_allocations.items():
            _resource_agent.consume_water(ml)
            water_cmds.append({"plant": plant_id, "ml": round(ml, 1)})
'''
if old not in text:
    raise SystemExit('water block not found')
text = text.replace(old, new)

old2 = '''                logger.warning(
                    "High humidity %.1f%% for %s — commanding lid open",
                    reading.humidity_pct, reading.plant_id,
                )
                actuate_servo_lid(_LID_OPEN_ANGLE)
                commands["servo_lid"] = {"angle": _LID_OPEN_ANGLE}
                asyncio.get_event_loop().call_later(
                    _LID_VENT_SEC, lambda: actuate_servo_lid(0)
                )
'''
new2 = '''                logger.warning(
                    "High humidity %.1f%% for %s — returning lid command",
                    reading.humidity_pct, reading.plant_id,
                )
                commands["servo_lid"] = {"angle": _LID_OPEN_ANGLE}
                commands["servo_lid_close_after_sec"] = _LID_VENT_SEC
'''
if old2 not in text:
    raise SystemExit('lid block not found')
text = text.replace(old2, new2)
path.write_text(text, encoding='utf-8')
print('updated', path)
