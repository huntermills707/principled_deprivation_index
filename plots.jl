using DataFrames
using KernelDensity
using Plots
using StatsPlots

function get_pair(df, col1, col2)
    """
    function to get data for a pair of columns.
    Drop any elements that are missing in either colums.
    """
    r = dropmissing(df[:,[col1, col2]])
    x = r[:, col1]
    y = r[:, col2]
    return x, y
end


function get_range(x)
    """
    function to get data range for plotting.
    IE. for ylims and xlims in plot functions.
    """
    m_x = median(x)
    dx_l = m_x - quantile(x, 0.16)
    dx_h = quantile(x, 0.84) - m_x
    xmin = m_x  - 3 * dx_l
    xmax = m_x + 3 * dx_h
    return xmin, xmax
end


function kde_subplots(df, col1, col2, name)
    """
    function to get subplots for Kernel Density plots.
    returns plot for 1D KDE for col1 and col2, and the 2D KDE of col1 and col2.
    """
    x, y = get_pair(df, col1, col2)

    xmin, xmax = get_range(x)
    ymin, ymax = get_range(y)

    ky = KernelDensity.kde(y)
    p_y = density(y, orientation=:h, ylims=(ymin, ymax), xlims=(0, 1.1 * maximum(ky.density)), 
                  legend=false,  ticks=nothing, xguide="", yguide="", ylabel="$(name) (%)")
 
    p_x = density(x, xlims=(xmin, xmax), legend=false, ticks=nothing, xguide="", yguide="", xlabel=col1)

    k = kde((x, y))
    p_xy = contour(collect(k.x), collect(k.y), k.density', colorbar=false, levels=10, ylims=(ymin, ymax), xlims=(xmin, xmax))

    return p_xy, p_x, p_y
end


function plot_county(df, col, name)
    """
    function to plot results of "col" for county data.
    county data compares:
     * PDI
     * NDI
     * SVI
     * NRI
    """
    mkpath("plots/county")

    i1_xy, i1_x, y = kde_subplots(df, :PDI, col, name)
    i2_xy, i2_x, _ = kde_subplots(df, :NDI, col, name)
    i3_xy, i3_x, _ = kde_subplots(df, :SVI, col, name)
    i4_xy, i4_x, _ = kde_subplots(df, :NRI, col, name)

    l = @layout [
        i1_x              i2_x               _; 
        i1_xy{0.45w,0.4h} i2_xy{0.45w,0.4h}  y; 
        i3_x              i4_x               _; 
        i3_xy{0.45w,0.4h} i4_xy{0.45w,0.4h}  y
    ]

    p = plot(i1_x, i2_x, i1_xy, i2_xy, y, i3_x, i4_x, i3_xy, i4_xy, y, 
             layout = l, 
             size=(800,600))
    savefig(p, """plots/county/$(col).png""")
end


function plot_zip(df, col, name)
    """
    function to plot results of "col" for zcta data.
    county data compares:
     * PDI
     * NDI
    """
    mkpath("plots/zcta")

    i1_xy, i1_x, y = kde_subplots(df, :PDI, col, name)
    i2_xy, i2_x, _ = kde_subplots(df, :NDI, col, name)

    l = @layout [
        i1_x              i2_x               _; 
        i1_xy{0.45w,0.9h} i2_xy{0.45w,0.9h}  y; 
    ]

    p = plot(i1_x, i2_x, i1_xy, i2_xy, y,
             layout = l, 
             size=(800,500))
    savefig(p, """plots/zcta/$(col).png""")
end


function plot_tract(df, col, name)
    """
    function to plot results of "col" for tract data.
    county data compares:
     * PDI
     * NDI
     * SVI
     * NRI
     * nSES
    """
    mkpath("plots/tract")

    i1_xy, i1_x, y = kde_subplots(df, :PDI, col, name)
    i2_xy, i2_x, _ = kde_subplots(df, :NDI, col, name)
    i3_xy, i3_x, _ = kde_subplots(df, :SVI, col, name)
    i4_xy, i4_x, _ = kde_subplots(df, :NRI, col, name)
    i5_xy, i5_x, _ = kde_subplots(df, :nSES, col, name)

    l = @layout [
      [i1_x               i2_x               i3_x              _;
       i1_xy{0.32w,0.9h}  i2_xy{0.32w,0.9h}  i3_xy{0.32w,0.9h} y]
      [_    i4_x              i5_x              _              _;
       _    i4_xy{0.32w,0.9h} i5_xy{0.32w,0.9h} y{0.04w,0.9h}  _]
    ]

    p = plot(i1_x, i2_x, i3_x , i1_xy, i2_xy, i3_xy, y, i4_x, i5_x, i4_xy, i5_xy, y, 
             layout = l, 
             size=(800,600))
    savefig(p, """plots/tract/$(col).png""")
end
