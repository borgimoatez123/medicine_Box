from gpiozero import Button

BUTTON_GPIO = 27

class ScreenButton:
    def __init__(self, on_press):
        self.button = Button(
            BUTTON_GPIO,
            pull_up=True,
            bounce_time=0.2
        )
        self.button.when_pressed = on_press

    def close(self):
        self.button.close()
