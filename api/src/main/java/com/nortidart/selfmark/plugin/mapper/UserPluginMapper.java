package com.nortidart.selfmark.plugin.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.nortidart.selfmark.plugin.entity.UserPlugin;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Result;
import org.apache.ibatis.annotations.Results;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface UserPluginMapper extends BaseMapper<UserPlugin> {
    @Select("SELECT * FROM user_plugin WHERE id = #{id} FOR UPDATE")
    @Results(id = "lockedUserPlugin", value = {
            @Result(column = "id", property = "id", id = true),
            @Result(column = "config", property = "config", typeHandler = JsonNodeTypeHandler.class)
    })
    UserPlugin selectByIdForUpdate(@Param("id") Long id);

    @Update("""
            UPDATE user_plugin
            SET config = #{config,typeHandler=com.nortidart.selfmark.plugin.mapper.JsonNodeTypeHandler}
            WHERE id = #{id} AND user_id = #{userId}
            """)
    int replaceConfig(@Param("id") Long id, @Param("userId") Long userId, @Param("config") JsonNode config);

    @Update("UPDATE user_plugin SET enabled = #{enabled} WHERE id = #{id} AND user_id = #{userId}")
    int setEnabled(@Param("id") Long id, @Param("userId") Long userId, @Param("enabled") boolean enabled);

    @Delete("DELETE FROM user_plugin WHERE id = #{id} AND user_id = #{userId}")
    int deleteOwned(@Param("id") Long id, @Param("userId") Long userId);
}
