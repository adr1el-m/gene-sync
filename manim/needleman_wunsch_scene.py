from manim import *


config.background_color = "#FEFAF4"
config.pixel_width = 1600
config.pixel_height = 800
config.frame_width = 16
config.frame_height = 8
config.frame_rate = 30


BG = "#FEFAF4"
MAROON = "#7A0B07"
RED = "#9B1C18"
INK = "#2D2520"
MUTED = "#5A524B"
GRID = "#8B8B8B"
LIGHT_GRID = "#D9D2C8"

SERIF = "Georgia"
MONO = "Menlo"


class NeedlemanWunschDemo(Scene):
    """GeneSync-style Needleman-Wunsch demonstration."""

    def construct(self):
        self.camera.background_color = BG

        title = self.make_text(
            "Computing the Best Alignment",
            size=0.36,
            color=MAROON,
            weight=BOLD,
        )
        title.move_to([-2.80, 3.50, 0], aligned_edge=LEFT)

        steps = self.make_steps()
        steps.move_to([-2.78, 3.13, 0], aligned_edge=LEFT)
        matrix_title = self.make_text(
            "Dynamic Programming Matrix",
            size=0.22,
            color=MAROON,
            weight=BOLD,
        )
        table, cells = self.make_matrix()
        matrix_group = VGroup(matrix_title, table).arrange(DOWN, buff=0.10)
        matrix_group.move_to([4.20, 1.05, 0])

        rules = self.make_rules()
        rules.move_to([7.40, 1.95, 0], aligned_edge=LEFT)
        traceback = self.make_traceback()
        traceback.move_to([7.40, -1.30, 0], aligned_edge=LEFT)
        example = self.make_example()
        example.move_to([-2.78, -3.24, 0], aligned_edge=LEFT)

        self.play(FadeIn(title, shift=DOWN * 0.1), run_time=0.8)
        self.play(FadeIn(steps, shift=DOWN * 0.08), run_time=0.6)
        self.play(FadeIn(matrix_title), Create(table), run_time=1.4)
        self.wait(0.4)
        self.play(FadeIn(rules, shift=LEFT * 0.15), run_time=1.0)

        self.matrix_phase(cells, example)
        self.traceback_phase(cells, traceback)
        self.alignment_phase(cells, traceback)
        self.wait(3)

    def matrix_phase(self, cells, example):
        row_header = [cells[(r, 1)] for r in range(2, 8)]
        column_header = [cells[(1, c)] for c in range(2, 10)]
        first_row = [cells[(2, c)] for c in range(2, 10)]
        first_column = [cells[(r, 2)] for r in range(2, 8)]

        row_flash = VGroup(*[cell.copy().set_fill("#E8DFD4", opacity=0.72) for cell in row_header])
        column_flash = VGroup(*[cell.copy().set_fill("#E8DFD4", opacity=0.72) for cell in column_header])
        self.play(FadeIn(row_flash), FadeIn(column_flash), run_time=0.45)
        self.wait(0.25)
        self.play(FadeOut(row_flash), FadeOut(column_flash), run_time=0.35)

        init_flash = VGroup(*[cell.copy().set_fill("#F2E8DD", opacity=0.82) for cell in first_row + first_column])
        self.play(FadeIn(init_flash), run_time=0.5)
        self.wait(0.35)
        self.play(FadeOut(init_flash), run_time=0.35)

        focus = SurroundingRectangle(cells[(3, 3)], color=RED, buff=0.015, stroke_width=3)
        self.play(Create(focus), FadeIn(example, shift=UP * 0.08), run_time=0.85)
        self.wait(1.2)
        self.play(Indicate(cells[(3, 3)], color=RED, scale_factor=1.05), run_time=0.7)
        self.wait(0.4)
        self.play(FadeOut(focus), run_time=0.3)

    def traceback_phase(self, cells, traceback):
        path = [(2, 2), (3, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (7, 9)]
        highlights = VGroup()
        for row, column in path:
            highlights.add(
                SurroundingRectangle(cells[(row, column)], color=RED, buff=0.015, stroke_width=2.7)
            )

        centers = [cells[key].get_center() for key in path]
        segments = VGroup()
        for start, end in zip(centers, centers[1:]):
            segments.add(Line(start, end, color=RED, stroke_width=2.0).add_tip(tip_length=0.10))

        self.play(LaggedStart(*[Create(box) for box in highlights], lag_ratio=0.13), run_time=1.4)
        self.play(LaggedStart(*[Create(segment) for segment in segments], lag_ratio=0.16), run_time=1.9)
        self.wait(0.6)
        self.play(FadeIn(traceback, shift=LEFT * 0.12), run_time=0.8)
        self.wait(1.0)

    def alignment_phase(self, cells, traceback):
        final_cell = cells[(7, 9)]
        score_box = SurroundingRectangle(final_cell, color=RED, buff=0.018, stroke_width=3.2)

        self.play(Create(score_box), run_time=0.7)
        self.wait(1.0)
        self.play(Indicate(traceback[-1], color=RED, scale_factor=1.1), run_time=0.8)
        self.wait(0.7)

    def make_matrix(self):
        labels = [
            ["", "□", "T", "T", "G", "A", "C", "G", "T"],
            ["□", "0", "-2", "-4", "-6", "-8", "-10", "-12", "-14"],
            ["T", "-2", "1", "-1", "-3", "-5", "-7", "-9", "-11"],
            ["G", "-4", "-1", "0", "0", "-2", "-4", "-6", "-8"],
            ["A", "-6", "-3", "-2", "-1", "1", "-1", "-3", "-5"],
            ["C", "-8", "-5", "-4", "-3", "-1", "2", "0", "-2"],
            ["G", "-10", "-7", "-6", "-3", "-3", "0", "3", "1"],
        ]

        cell_w = 0.56
        cell_h = 0.43
        cells = {}
        group = VGroup()

        for r, row in enumerate(labels):
            for c, value in enumerate(row):
                rect = Rectangle(
                    width=cell_w,
                    height=cell_h,
                    stroke_color=GRID,
                    stroke_width=1.0,
                    fill_color=BG,
                    fill_opacity=1,
                )
                rect.move_to(RIGHT * (c * cell_w) + DOWN * (r * cell_h))
                cells[(r + 1, c + 1)] = rect

                if value:
                    font = MONO if value.replace("-", "").isdigit() else SERIF
                    text = Text(value, font=font, font_size=17, color=INK)
                    text.move_to(rect.get_center())
                    group.add(rect, text)
                else:
                    group.add(rect)

        group.move_to(ORIGIN)
        return group, cells

    def make_steps(self):
        group = VGroup()
        items = [
            ("Steps:", MAROON, BOLD),
            ("1. Matrix", INK, NORMAL),
            ("2. Traceback", INK, NORMAL),
            ("3. Alignment", INK, NORMAL),
        ]

        cursor = ORIGIN
        for text, color, weight in items:
            item = self.make_text(text, 0.20, color, weight)
            item.move_to(cursor, aligned_edge=LEFT)
            group.add(item)
            cursor += RIGHT * (item.width + 0.30)

        return group

    def make_rules(self):
        title_text = self.make_text("Rules", 0.27, MAROON, BOLD)
        title = VGroup(title_text, Underline(title_text, color=MAROON, buff=0.03, stroke_width=1.5))
        bullets = VGroup(
            self.bullet("Matches = +1"),
            self.bullet("Mismatches = -1"),
            self.bullet("Gaps = -2"),
            self.bullet("Horizontal/Vertical = Gap"),
            self.bullet("Diagonal = Match/Mismatch"),
            self.bullet("Highest # wins!"),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.12)

        group = VGroup(title, bullets).arrange(DOWN, aligned_edge=LEFT, buff=0.12)
        return group

    def make_traceback(self):
        title = self.make_text("Traceback  Result:", 0.27, MAROON, BOLD)
        line1 = self.make_text("T T G A C G T", 0.20, INK)
        line2 = self.make_text("T - G A C G -", 0.20, INK)
        score_line = self.make_text("Score: 1", 0.18, MUTED)
        group = VGroup(title, line1, line2, score_line).arrange(DOWN, aligned_edge=LEFT, buff=0.10)
        return group

    def make_example(self):
        start = self.make_text("Example - cell (1, 1):", 0.20, INK, BOLD)
        calc = self.make_text(
            "-2 + (-2) = -4,    -2 + (-2) = -4,    0 + 1 = 1*",
            0.23,
            INK,
        )
        start.move_to([0, 0, 0], aligned_edge=LEFT)
        calc.move_to([2.28, 0, 0], aligned_edge=LEFT)
        pieces = VGroup(start, calc)
        calc_left = calc.get_left()

        brace1 = BraceBetweenPoints(
            calc_left + RIGHT * 0.28 + DOWN * 0.18,
            calc_left + RIGHT * 1.12 + DOWN * 0.18,
            direction=DOWN,
            color=INK,
        )
        brace2 = BraceBetweenPoints(
            calc_left + RIGHT * 2.62 + DOWN * 0.18,
            calc_left + RIGHT * 3.46 + DOWN * 0.18,
            direction=DOWN,
            color=INK,
        )
        brace3 = BraceBetweenPoints(
            calc_left + RIGHT * 5.04 + DOWN * 0.18,
            calc_left + RIGHT * 5.55 + DOWN * 0.18,
            direction=DOWN,
            color=INK,
        )

        label1 = self.make_text("gap", 0.13, INK).next_to(brace1, DOWN, buff=0.02)
        label2 = self.make_text("gap", 0.13, INK).next_to(brace2, DOWN, buff=0.02)
        label3 = self.make_text("match", 0.13, INK).next_to(brace3, DOWN, buff=0.02)
        winner = Rectangle(width=0.27, height=0.26, stroke_color=RED, stroke_width=1.6)
        winner.move_to(calc.get_right() + LEFT * 0.10 + DOWN * 0.01)

        group = VGroup(pieces, brace1, brace2, brace3, label1, label2, label3, winner)
        return group

    def bullet(self, text):
        dot = Dot(radius=0.028, color=MAROON)
        label = self.make_text(text, 0.20, MUTED)
        dot.next_to(label, LEFT, buff=0.12)
        return VGroup(dot, label)

    def make_text(self, text, size, color=INK, weight=NORMAL):
        return Text(text, font=SERIF, font_size=size * 72, color=color, weight=weight)


if __name__ == "__main__":
    scene = NeedlemanWunschDemo()
    scene.render()
