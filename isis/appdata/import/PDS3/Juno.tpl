{% extends "img_base.tpl" %}


{% block instrument %}
SpacecraftName                  = {{SPACECRAFT_NAME.Value}}
InstrumentHostId                = {{INSTRUMENT_HOST_ID.Value}}
SpacecraftId                    = {{INSTRUMENT_HOST_ID.Value}}
InstrumentName                  = {{INSTRUMENT_NAME.Value}}
InstrumentId                    = {{INSTRUMENT_ID.Value}}
TargetName                      = {{TARGET_NAME.Value}}
StartTime                       = {{START_TIME.Value}}
SpacecraftClockStartCount       = {{SPACECRAFT_CLOCK_START_COUNT.Value}}
ExposureDuration                = {{EXPOSURE_DURATION.Value}}
InterFrameDelay                 = {{INTERFRAME_DELAY.Value}}
SummingMode                     = {{SAMPLING_FACTOR.Value}}

{% endblock %}

{% block additional_groups %}
Group = Archive
    MissionPhase                = {{MISSION_PHASE_NAME.Value}}
    OrbitNumber                 = {{ORBIT_NUMBER.Value}}
    FocalPlaneTemperature       = {{FOCAL_PLANE_TEMPERATURE.Value}}
    TDICount                    = {{JNO_TDI_STAGES_COUNT.Value}}
    CompressionType             = {{COMPRESSION_TYPE.Value}}
End_Group

Group = BandBin
    FilterName                  = {{FILTER_NAME.Value}}
    NaifIkCode                  = "-61502"
End_Group

{% block kernels %}
  NaifFrameCode = "-61500"
{% endblock %}
