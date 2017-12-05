abstract class Filter {
    abstract PImage run(PImage input);
}

abstract class ManagedFilter extends Filter {
    int width(PImage input) {
        return input.width;
    }

    int height(PImage input) {
        return input.height;
    }

    abstract void runWithStore(PImage input, PImage store);

    final PImage run(PImage input) {
        PImage result = createImage(width(input), height(input), RGB);
        result.loadPixels();
        input.loadPixels();
        runWithStore(input, result);
        result.updatePixels();
        return result;
    }
}

abstract class InPlaceFilter extends ManagedFilter {
    final void runInPlace(PImage input) {
        input.loadPixels();
        assert width(input) <= input.width && height(input) <= input.height;
        runWithStore(input, input);
        input.updatePixels();
    }
}
