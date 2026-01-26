"""Application Entry"""

from pathlib import Path

from kivy.config import Config
from kivy.core.text import LabelBase, DEFAULT_FONT
from kivy.resources import resource_add_path

from .derenotes import DerenotesApp

log_dir = str(Path().absolute()) + "/logs"

## Settings Kivy - graphics ##
# fullscreen: 0, 1, "auto", "fake"
# borderless: 0, 1
# custom_titlebar: 0, 1
# width: not used if fullscreen is set to "auto".
# height: not used if fullscreen is set to "auto".
# show_cursor: 0, 1
Config.set("graphics", "fullscreen", 0)
Config.set("graphics", "borderless", 0)
Config.set("graphics", "custom_titlebar", 0)
Config.set("graphics", "height", 850)
Config.set("graphics", "width", 550)
Config.set("graphics", "show_cursor", 0)

## Settings Kivy - kivy ##
# log_level: "trace", "debug", "info", "warning", "error", "critical"
Config.set("kivy", "log_dir", log_dir)
Config.set("kivy", "log_level", "info")
Config.set("kivy", "log_maxfiles", 10)
Config.set("kivy", "keyboard_mode", "")

## To use japanese font in Kivy
# resource_add_path("/usr/share/fonts/opentype/ipaexfont-gothic")
# LabelBase.register(DEFAULT_FONT, "ipaexg.ttf")
resource_add_path("/usr/share/fonts/opentype/ipafont-gothic")
LabelBase.register(DEFAULT_FONT, "ipag.ttf")

DerenotesApp().run()
