ObjC.import("AppKit");

JSON.stringify(
	$.NSScreen.screens.js.map((screen) => {
		const left = screen.auxiliaryTopLeftArea;
		const right = screen.auxiliaryTopRightArea;

		const encode = (rect) =>
			rect
				? {
						x: Number(rect.origin.x),
						w: Number(rect.size.width),
						h: Number(rect.size.height),
					}
				: null;

		return { left: encode(left), right: encode(right) };
	}),
);
