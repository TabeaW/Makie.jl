"""
    hexbin(xs, ys; kwargs...)

Plots a heatmap with hexagonal bins for the observations `xs` and `ys`.

## Attributes
### Specific to `Hexbin`
* `gridsize::Int = 20` sets the number of bins in x-direction
* `mincnt::Int = 0` sets the minimal number of observations in the bin to be shown. If 0 all bins are shown, if 1 all with at least 1 observation.
* `scale = identity` scales the number of data in the bins, eg. log10.
### Generic
* `colormap::Union{Symbol, Vector{<:Colorant}} = :viridis` sets the colormap that is sampled for numeric colors.
* `colorrange::Tuple(<:Real,<:Real} = Makie.automatic`  sets the values representing the start and end points of `colormap`.
"""
@recipe(Hexbin) do scene
    Attributes(;
    colormap = theme(scene, :colormap),
    colorrange=Makie.automatic,
    gridsize = 20,
    mincnt = 0,
    scale=identity)
end

function Makie.plot!(hb::Hexbin{<:Tuple{<:AbstractVector{<:Any}, <:AbstractVector{<:Any}}})
    x,y =hb[1:2]
   
    polys = Observable(Polygon[])
    count_hex=Observable(Float64[])
    function calculate_grid(x,y,grid_size,mincnt,scale)
        empty!(polys[])
        empty!(count_hex[])
        if (length(x)==0)|(length(y)==0)
            return
        end
        axis = current_axis()
        x_axis = false
        y_axis = false
        if isnothing(axis)
            x_diff = maximum(x)-minimum(x)
            y_diff = maximum(y)-minimum(y)
        else
            if ! isnothing(axis.limits[][1])& ! isnothing(axis.limits[][2])
            x_diff = axis.limits[][2]- axis.limits[][1]
            x_axis = true
            y = y[(x.<=axis.limits[][2]).&(x.>=axis.limits[][1])]
            x = x[(x.<=axis.limits[][2]).&(x.>=axis.limits[][1])]
            else
            x_diff = maximum(x)-minimum(x)

            end
            if (length(axis.limits[])==4) ! isnothing(axis.limits[][3])& ! isnothing(axis.limits[][4])
                y_diff = axis.limits[][4]- axis.limits[][3]
                y_axis=true
                x = x[(y.<=axis.limits[][4]).&(y.>=axis.limits[][3])]
                y = y[(y.<=axis.limits[][4]).&(y.>=axis.limits[][3])]
            else
                y_diff = maximum(y)-minimum(y)
            end
        end
        
        scaling_x = 1
        scaling_y = 1
        if x_diff>y_diff
            scaling_y =x_diff/y_diff
        else
            scaling_x = y_diff/x_diff
        end
        y_copy = y.*scaling_y
        x_copy = x.*scaling_x
        if x_axis
            min_x,max_x = axis.limits[][1:2]
        else
            min_x,max_x =extrema(x_copy)
        end
        if y_axis
            min_y,max_y = axis.limits[][3:4]
        else
            min_y,max_y = extrema(y_copy)
        end
        r = (max_x-min_x)/((grid_size-2)*2) 
        x_odd_grid =min_x-r:sin(pi/3)*2*r:max_x-r
        x_even_grid = min_x+sin(pi/3)*r:sin(pi/3)*2*r:max_x-r
        y_odd_grid = min_y:3*r:max_y
        y_even_grid = min_y+3/2*r:3*r:max_y-3/2*r
        grid_points = Point2f[]
        for i in x_odd_grid
            for j in y_odd_grid
                push!(grid_points,Point2f(i+r,j))
            end
        end
        for i in x_even_grid
            for j in y_even_grid
                push!(grid_points,Point2f(i,j))
            end
        end
        values = Point2f.(x_copy,y_copy)
        tree = KDTree(grid_points)
        ind,dist = nn(tree,values)
        amount_hex = zeros(size(grid_points))
        for i in ind
            amount_hex[i]+=1
        end
        grid_points=grid_points[amount_hex.>=mincnt]
        amount_hex=amount_hex[amount_hex.>=mincnt]      
        amount_hex = scale.(amount_hex)

        xe = sin.(0:pi/3:5/3*pi)
        ys = cos.(0:pi/3:5/3*pi)
        hex_points=Point2f[]
        for (a,b) in zip(xe,ys)
            push!(hex_points, Point2f(a*r*1/scaling_x,b*r*1/scaling_y))
        end
        hex = [Polygon(hex_points.+p*Point2f(1/scaling_x,1/scaling_y)) for p in grid_points]

        for b in hex
            push!(polys[],b)
        end
        for a in amount_hex
            push!(count_hex[],a)
        end

    end
    onany(calculate_grid,x,y,hb.gridsize, hb.mincnt,hb.scale)
    calculate_grid(x[],y[],hb.gridsize[],hb.mincnt[],hb.scale[])

    replace_automatic!(hb,:colorrange)do 
        if isempty(count_hex[])
            (0,1)
        else
            (minimum(count_hex[]),maximum(count_hex[]) )
        end
    end 
    if ! isempty(polys[])
        poly!(hb,polys,color=count_hex,colormap=hb.colormap)
    end
end
