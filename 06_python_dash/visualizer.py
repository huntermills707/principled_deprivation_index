from json import load

import dash
from dash import dcc, html
from dash.dependencies import Input, Output, State
import plotly.express as px
import pandas as pd
import numpy as np
import requests

counties = None
with open('geojson-counties-fips-post-2024.json') as fp:
    counties = load(fp)

for feature in counties['features']:
    feature['id'] = feature['properties']['STATE'] + feature['properties']['COUNTY']

# Extract all FIPS codes from the GeoJSON
fips_codes = [feature['id'] for feature in counties['features']]

# Create DataFrame with FIPS codes and two random numbers per county
df = pd.read_csv('../final/county_results.csv')
df['COUNTY'] = df['COUNTY'].astype(str).str.zfill(5)

conditions = [
    ("mhlth_crudeprev", "Poor mental health"),
    ("cognition_crudeprev", "Cognitive disability"),
    ("pct_disabled", "Disability"),
    ("mobility_crudeprev", "Mobility disability"),
    ("selfcare_crudeprev", "Self-care disability"),
    ("indeplive_crudeprev", "Independent living\ndisability"),
    ("hearing_crudeprev", "Hearing disability"),
    ("vision_crudeprev", "Vision disability"),
    ("phlth_crudeprev", "Poor physical health"),
    ("ghlth_crudeprev", "Poor self-rated health"),
    ("diabetes_crudeprev", "Diabetes"),
    ("stroke_crudeprev", "Stroke"),
    ("bphigh_crudeprev", "High blood pressure"),
    ("copd_crudeprev", "Chronic obstructive\npulmonary disease"),
    ("arthritis_crudeprev", "Arthritis"),
    ("obesity_crudeprev", "Obesity"),
    ("teethlost_crudeprev", "All teeth lost"),
    ("highchol_crudeprev", "High cholesterol"),
    ("casthma_crudeprev", "Asthma"),
    ("cancer_crudeprev", "Cancer (non-skin)\nor melanoma"),
    ("chd_crudeprev", "Coronary heart disease"),
]

indices = [
    ("PDI", "Principled Deprivation Index"),
    ("NDI", "Neighborhood Deprivation Index"),
    ("SVI", "Social Vulnerability Index"),
    ("NRI", "National Risk Index Score"),
]

labels = {k:v for k,v in conditions + indices}

indices_labels = [{'label': k, 'value': v} for v,k in indices]

conditions_labels = [{'label': k, 'value': v} for v,k in conditions]

# Extract state FIPS codes from county FIPS codes (first 2 characters)
df['state_fips'] = df['COUNTY'].str[:2]

# Create a mapping from state FIPS codes to state names
state_fips_to_name = {
    '01': 'Alabama', '02': 'Alaska', '04': 'Arizona', '05': 'Arkansas',
    '06': 'California', '08': 'Colorado', '09': 'Connecticut', '10': 'Delaware',
    '11': 'District of Columbia', '12': 'Florida', '13': 'Georgia', '15': 'Hawaii',
    '16': 'Idaho', '17': 'Illinois', '18': 'Indiana', '19': 'Iowa', '20': 'Kansas',
    '21': 'Kentucky', '22': 'Louisiana', '23': 'Maine', '24': 'Maryland',
    '25': 'Massachusetts', '26': 'Michigan', '27': 'Minnesota', '28': 'Mississippi',
    '29': 'Missouri', '30': 'Montana', '31': 'Nebraska', '32': 'Nevada',
    '33': 'New Hampshire', '34': 'New Jersey', '35': 'New Mexico', '36': 'New York',
    '37': 'North Carolina', '38': 'North Dakota', '39': 'Ohio', '40': 'Oklahoma',
    '41': 'Oregon', '42': 'Pennsylvania', '44': 'Rhode Island', '45': 'South Carolina',
    '46': 'South Dakota', '47': 'Tennessee', '48': 'Texas', '49': 'Utah',
    '50': 'Vermont', '51': 'Virginia', '53': 'Washington', '54': 'West Virginia',
    '55': 'Wisconsin', '56': 'Wyoming'
}

# Center coordinates for each state
state_centers = {
    '01': {'lat': 32.806671, 'lon': -86.791130},
    '02': {'lat': 61.370716, 'lon': -152.404419},
    '04': {'lat': 33.729759, 'lon': -111.431221},
    '05': {'lat': 34.969704, 'lon': -92.373123},
    '06': {'lat': 36.116203, 'lon': -119.681564},
    '08': {'lat': 39.059811, 'lon': -105.311104},
    '09': {'lat': 41.597782, 'lon': -72.755371},
    '10': {'lat': 38.910532, 'lon': -75.528012},
    '11': {'lat': 38.899348, 'lon': -77.014567},
    '12': {'lat': 27.766279, 'lon': -82.776462},
    '13': {'lat': 33.247875, 'lon': -83.441162},
    '15': {'lat': 20.7167, 'lon': -157.75},
    '16': {'lat': 44.2405, 'lon': -114.4788},
    '17': {'lat': 40.6331, 'lon': -89.3985},
    '18': {'lat': 39.8494, 'lon': -86.2583},
    '19': {'lat': 42.0052, 'lon': -93.6318},
    '20': {'lat': 38.5266, 'lon': -96.7265},
    '21': {'lat': 37.8393, 'lon': -84.2700},
    '22': {'lat': 30.9843, 'lon': -91.9623},
    '23': {'lat': 45.2538, 'lon': -69.4455},
    '24': {'lat': 39.0639, 'lon': -76.8021},
    '25': {'lat': 42.2302, 'lon': -71.5301},
    '26': {'lat': 44.3467, 'lon': -85.4102},
    '27': {'lat': 46.3971, 'lon': -94.6362},
    '28': {'lat': 32.7416, 'lon': -89.6787},
    '29': {'lat': 38.5739, 'lon': -92.6038},
    '30': {'lat': 46.8797, 'lon': -110.3626},
    '31': {'lat': 41.4925, 'lon': -99.9018},
    '32': {'lat': 38.3135, 'lon': -117.0554},
    '33': {'lat': 43.8041, 'lon': -71.1108},
    '34': {'lat': 40.2989, 'lon': -74.5210},
    '35': {'lat': 34.8405, 'lon': -106.2485},
    '36': {'lat': 42.9595, 'lon': -75.5267},
    '37': {'lat': 35.6301, 'lon': -79.8064},
    '38': {'lat': 47.5515, 'lon': -101.0020},
    '39': {'lat': 40.2521, 'lon': -83.6197},
    '40': {'lat': 35.5653, 'lon': -96.9289},
    '41': {'lat': 44.5720, 'lon': -122.0709},
    '42': {'lat': 41.2033, 'lon': -77.1945},
    '44': {'lat': 41.6809, 'lon': -71.5118},
    '45': {'lat': 33.6874, 'lon': -80.4551},
    '46': {'lat': 43.9695, 'lon': -99.9018},
    '47': {'lat': 35.7478, 'lon': -86.6923},
    '48': {'lat': 31.0545, 'lon': -97.5635},
    '49': {'lat': 39.4192, 'lon': -111.9507},
    '50': {'lat': 44.0459, 'lon': -72.7107},
    '51': {'lat': 37.5042, 'lon': -78.4890},
    '53': {'lat': 47.4006, 'lon': -121.4908},
    '54': {'lat': 38.4680, 'lon': -80.9999},
    '55': {'lat': 44.2685, 'lon': -89.8164},
    '56': {'lat': 42.9958, 'lon': -107.5512}
}

# Default center for USA
usa_center = {'lat': 37.0902, 'lon': -95.7129}

# Get list of states in the data
valid_states = [k for k in state_fips_to_name.keys() if df['state_fips'].str.startswith(k).any()]

# Sort state names alphabetically
state_names = ['All USA'] + sorted([state_fips_to_name[fips] for fips in valid_states])

# Initialize Dash app
app = dash.Dash(__name__)

app.layout = html.Div([
    html.H1("Index:Condition Synced County Choropleth Maps", style={'textAlign': 'center'}),

    html.Div([
        html.Label("Select State:", style={'fontWeight': 'bold'}),
        dcc.Dropdown(
            id='state-dropdown',
            options=[{'label': state, 'value': state} for state in state_names],
            value='All USA',
            style={'width': '100%'}
        )
    ], style={'width': '50%', 'margin': '0 auto', 'padding': '10px'}),

    html.Div([
        # Left map (Value 1)
        html.Div([
            html.Label("Select Index:", style={'fontWeight': 'bold'}),
            dcc.Dropdown(
                id='index-dropdown',
                options=indices_labels,
                value='PDI',
                style={'width': '100%'}
            )
        ], style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),

        # Right map (Value 2)
        html.Div([
            html.Label("Select Outcome:", style={'fontWeight': 'bold'}),
            dcc.Dropdown(
                id='outcome-dropdown',
                options=conditions_labels,
                value='phlth_crudeprev',
                style={'width': '100%'}
            )
        ], style={'width': '48%', 'display': 'inline-block', 'padding': '1%'})
    ]),

    html.Div([
        # Left map (Value 1)
        html.Div([
            dcc.Graph(
                id='map1',
                config={'scrollZoom': True},
                style={'height': '600px'}
            )
        ], style={'width': '48%', 'display': 'inline-block', 'padding': '1%'}),

        # Right map (Value 2)
        html.Div([
            dcc.Graph(
                id='map2',
                config={'scrollZoom': True},
                style={'height': '600px'}
            )
        ], style={'width': '48%', 'display': 'inline-block', 'padding': '1%'})
    ]),

    # Store to hold the current viewport state
    dcc.Store(id='viewport-store', data={'center': usa_center, 'zoom': 3})
])

# Merged callback to handle both state selection and viewport syncing
@app.callback(
    [Output('map1', 'figure'),
     Output('map2', 'figure'),
     Output('viewport-store', 'data')],
    [Input('state-dropdown', 'value'),
     Input('index-dropdown', 'value'),
     Input('outcome-dropdown', 'value'),
     Input('map1', 'relayoutData'),
     Input('map2', 'relayoutData')],
    [State('viewport-store', 'data')]
)
def update_maps(selected_state, selected_index, selected_outcome, relayout1, relayout2, current_viewport):
    # Determine which input triggered the update
    ctx = dash.callback_context
    triggered_id = ctx.triggered[0]['prop_id'] if ctx.triggered else None

    # Filter data and GeoJSON based on selected state
    if selected_state != 'All USA':
        state_fips = next((k for k, v in state_fips_to_name.items() if v == selected_state), None)
        df_filtered = df[df['state_fips'] == state_fips]
        counties_filtered = {
            'type': 'FeatureCollection', 
            'features': [f for f in counties['features'] if f['id'].startswith(state_fips)]
        }
        # Set default viewport for the selected state
        viewport = {
            'center': state_centers.get(state_fips, usa_center),
            'zoom': 4
        }
    else:
        df_filtered = df
        counties_filtered = counties
        viewport = {
            'center': usa_center,
            'zoom': 3
        }

    # Update viewport based on map interactions (sync functionality)
    new_viewport = viewport.copy()

    if triggered_id == 'map1.relayoutData' and relayout1:
        # Map 1 was interacted with - sync viewport
        if 'map.center' in relayout1:
            new_viewport['center'] = relayout1['map.center']
        if 'map.zoom' in relayout1:
            new_viewport['zoom'] = relayout1['map.zoom']
    elif triggered_id == 'map2.relayoutData' and relayout2:
        # Map 2 was interacted with - sync viewport
        if 'map.center' in relayout2:
            new_viewport['center'] = relayout2['map.center']
        if 'map.zoom' in relayout2:
            new_viewport['zoom'] = relayout2['map.zoom']
    elif triggered_id == 'state-dropdown.value':
        # State was changed - use the state's default viewport
        new_viewport = viewport

    # Create Map 1 (Value 1)
    fig1 = px.choropleth_map(
        df_filtered,
        geojson=counties_filtered,
        locations='COUNTY',
        color=selected_index,
        hover_data ={selected_index: ':.3f', selected_outcome: ":.2f"},
        color_continuous_scale="Plasma",
        zoom=new_viewport['zoom'],
        center=new_viewport['center'],
        opacity=0.7,
        labels=labels
    )
    fig1.update_layout(
        title_text=f"Index Map: {labels[selected_index]}",
        margin={"r":0,"t":30,"l":0,"b":0},
        map_style="carto-positron"
    )

    # Create Map 2 (Value 2)
    fig2 = px.choropleth_map(
        df_filtered,
        geojson=counties_filtered,
        locations='COUNTY',
        color=selected_outcome,
        hover_data ={selected_index: ':.3f', selected_outcome: ":.2f"},
        color_continuous_scale="Plasma",
        zoom=new_viewport['zoom'],
        center=new_viewport['center'],
        opacity=0.7,
        labels=labels
    )
    fig2.update_layout(
        title_text=f"Outcome Map: {labels[selected_outcome]}",
        margin={"r":0,"t":30,"l":0,"b":0},
        map_style="carto-positron"
    )

    return fig1, fig2, new_viewport

if __name__ == '__main__':
    app.run(debug=False, threaded=True, port=8050)
