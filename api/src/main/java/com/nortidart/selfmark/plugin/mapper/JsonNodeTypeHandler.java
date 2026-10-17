package com.nortidart.selfmark.plugin.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.json.JsonMapper;
import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;

public class JsonNodeTypeHandler extends BaseTypeHandler<JsonNode> {
    private static final JsonMapper MAPPER = JsonMapper.builder()
            .enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS)
            .build();

    @Override
    public void setNonNullParameter(PreparedStatement statement, int index,
                                    JsonNode value, JdbcType jdbcType) throws SQLException {
        statement.setString(index, value.toString());
    }

    @Override
    public JsonNode getNullableResult(ResultSet result, String column) throws SQLException {
        return parse(result.getString(column));
    }

    @Override
    public JsonNode getNullableResult(ResultSet result, int column) throws SQLException {
        return parse(result.getString(column));
    }

    @Override
    public JsonNode getNullableResult(CallableStatement statement, int column) throws SQLException {
        return parse(statement.getString(column));
    }

    private JsonNode parse(String value) throws SQLException {
        if (value == null) {
            return null;
        }
        try {
            return MAPPER.readTree(value);
        } catch (JsonProcessingException exception) {
            throw new SQLException("Invalid stored plugin JSON", exception);
        }
    }
}
