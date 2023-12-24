# 1 PACKAGES

libs <- c(
    "giscoR", "terra", "sf",
    "elevatr", "png", "rayshader"
)

installed_libs <- libs %in% rownames(
    installed.packages()
)

if(any(installed_libs == F)){
    install.packages(
        libs[!installed_libs],
        dependencies = T
    )
}

invisible(
    lapply(
        libs, library,
        character.only = T
    )
)

# 2. AFRICA, ASIA and EUROPE SHAFILE

africa_sf <- giscoR::gisco_get_countries(
    region = c(
        "Africa", "Asia", "Europe"
    ),
    resolution = "3"
) |>
sf::st_union()

plot(sf::st_geometry(africa_sf))

# 3. NORTH AFRICA OLD TOPO MAP

north_africa_topo_tif <- terra::rast(
    "north_africa_topo.tif"
)

terra::plotRGB(north_africa_topo_tif)

# 4. NORTH AFRICA EXTENT

north_africa_bbox <- terra::ext(
    north_africa_topo_tif
) |>
    sf::st_bbox(crs = 3857) |>
    sf::st_as_sfc(crs = 3857) |>
    sf::st_transform(crs = 4326) |>
    sf::st_intersection(africa_sf)

plot(sf::st_geometry(north_africa_bbox))

# 5. NORTH AFRICA ELEVATION

north_africa_dem <- elevatr::get_elev_raster(
    locations = north_africa_bbox,
    z = 5, clip = "bbox"
)

north_africa_dem_3857 <- north_africa_dem |>
    terra::rast() |>
    terra::project("EPSG:3857")

terra::plot(north_africa_dem_3857)

# 6. RESAMPLE OLD TOPO MAP

north_africa_topo_resampled <- terra::resample(
    x = north_africa_topo_tif,
    y = north_africa_dem_3857,
    method = "bilinear"
)

img_file <- "north_africa_topo_modified.png"

terra::writeRaster(
    north_africa_topo_resampled,
    img_file,
    overwrite = T,
    NAflag = 255
)

north_africa_topo_img <- png::readPNG(
    img_file
)

# 7. RENDER SCENE

h <- nrow(north_africa_dem_3857)
w <- ncol(north_africa_dem_3857)

north_africa_matrix <- rayshader::raster_to_matrix(
    north_africa_dem_3857
)

north_africa_matrix |>
    rayshader::height_shade(
        texture = colorRampPalette(
            c("white", "grey80")
        )(128)
    ) |>
    rayshader::add_overlay(
        north_africa_topo_img,
        alphalayer = 1
    ) |>
    rayshader::plot_3d(
        north_africa_matrix,
        zscale = 17,
        solid = F,
        shadow = T,
        shadow_darkness = 1,
        background = "white",
        windowsize = c(
            w / 5, h / 5
        ),
        zoom = .42,
        phi = 89,
        theta = 0
    )

# 8. RENDER IMAGE

rayshader::render_highquality(
    filename = "3d_topo_north_africa.png",
    preview = T,
    interactive = F,
    light = F,
    environment_light = "air_museum_playground_4k.hdr",
    intensity_env = .75,
    rotate_env = 90,
    parallel = T,
    width = w * 1.5,
    height = h * 1.5
)
