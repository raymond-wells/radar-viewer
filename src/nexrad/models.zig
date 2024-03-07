/// Specifies how to convert raw radar data levels into physical
/// values. Radar products are each assigned a specific conversion mode,
/// with parameters present in the product header.
///
/// ## Data Range
///
/// Radial products **generally** reserve the first two data levels (0,1) as
/// error codes, 0 typically indicating below threshold, one indicating a "bad value"
/// condition or range folding. Hence the conversion formulae below specify (data - 2).
///
pub const DecodingParameters = union(enum) {
    /// Data levels should be treated as offsets from a fixed minimum value,
    /// scaled by the `increment` coefficient. Per ICD 2620001AB, the "true"
    /// data levels begin at 2, hence the conversion formula below offsets the
    /// raw data value by 2.
    ///
    /// physical = (data - 2) * increment + min_value
    MinWithIncrement: packed struct {
        min_value: f32,
        increment: f32,
        num_levels: u32,
    },

    /// Enhanced Echo Tops have their own unique conversion mechanism. Data may have an additional
    /// "topped" condition, computed by a bitwise operation: `data & topped`.
    ///
    /// physical = ((data & data_mask) / data_scale) - data_offset
    EchoTops: packed struct {
        topped_mask: u8,
        data_mask: u8,
        data_scale: f32,
        data_offset: f32,
    },

    /// Typically reserved for correlation coefficient, and differential products.
    /// ICD 2620001AB does not specify subtraction of the `leading_flags` value when
    /// computing the physical units.
    ///
    /// physical = (data - offset) / scale
    ScaledWithOffset: packed struct {
        scale: f32,
        offset: f32,
        max_data_level: u32,
        leading_flags: u32,
    },
};
