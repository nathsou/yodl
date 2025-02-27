# Noise

This example showcases how to display random noise via a VGA interface at a 640x480 resolution and a 60 Hz refresh rate.

First let's define a module capable of generating VGA pulse signals.

```yodl
{{#include ../../../examples/lib/VGA.yodl}}
```

Next, we define a Linear Feedback Shift Register (LFSR) module to generate random values.

```yodl
{{#include ../../../examples/lib/LFSR.yodl}}
```

<div class="warning">
    Note that only one branch in the match expression will be included in the final design dependending on the concrete value of the `NumBits` parameter.
</div>

Finally, we combine the `VGA` and `LFSR` modules to display random noise on the screen.

```yodl
{{#include ../../../examples/Noise.yodl}}
```
