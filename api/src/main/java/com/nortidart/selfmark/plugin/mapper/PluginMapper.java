package com.nortidart.selfmark.plugin.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nortidart.selfmark.plugin.dto.MarketPluginResponse;
import com.nortidart.selfmark.plugin.entity.Plugin;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Result;
import org.apache.ibatis.annotations.Results;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface PluginMapper extends BaseMapper<Plugin> {
    @Select("""
            SELECT p.id, p.code, p.name, p.description, p.sort,
                   up.id AS user_plugin_id, up.enabled, up.config
            FROM plugin p
            LEFT JOIN user_plugin up
              ON up.plugin_id = p.id AND up.user_id = #{userId}
            ORDER BY p.sort ASC, p.id ASC
            """)
    @Results(id = "marketPlugin", value = {
            @Result(column = "id", property = "id", id = true),
            @Result(column = "user_plugin_id", property = "userPluginId"),
            @Result(column = "config", property = "config", typeHandler = JsonNodeTypeHandler.class)
    })
    List<MarketPluginResponse> selectMarket(@Param("userId") Long userId);
}
